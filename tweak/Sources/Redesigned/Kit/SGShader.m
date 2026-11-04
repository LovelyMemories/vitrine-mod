#import "SGShader.h"
#import <string.h>
#import "Core/SGCore.h"
#import "SGRFluid.h"

// The shaders, as Metal source. They are compiled at runtime so that a tree without a .metal target still builds
// (see SGShader.h). The fragment shaders are kept plain: a fullscreen triangle, the frame's time and size, and a
// texture to read.
static NSString *const kShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"\n"
"struct SGAVertex { float4 position [[position]]; float2 uv; };\n"
"\n"
"// One triangle large enough for the whole screen, its uv running 0...1 across it.\n"
"vertex SGAVertex sgaFullscreen(uint vid [[vertex_id]]) {\n"
"    float2 p = float2((vid << 1) & 2, vid & 2);\n"
"    SGAVertex out;\n"
"    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);\n"
"    out.uv = float2(p.x, 1.0 - p.y);\n"
"    return out;\n"
"}\n"
"\n"
"// Dither: a stable hash of the pixel and the frame, so a flat colour on an OLED screen does not band.\n"
"static inline float sgaPixelHash(float2 p, uint seed) {\n"
"    uint h = uint(p.x) * 1597334677u ^ uint(p.y) * 3812015801u ^ seed * 2654435761u;\n"
"    h ^= h >> 13; h *= 0x5bd1e995u; h ^= h >> 15;\n"
"    return float(h & 0xFFFFu) / 65535.0;\n"
"}\n"
"\n"
"// The newer build of the mod's own shader library, taken as it stands (docs/chroma-ambient.metal): integer\n"
"// hashing that stays put at large coordinates, value noise with a quintic fade, fBm over it, and the colour\n"
"// space its ambient light is mixed in.\n"
"inline uint sgaHashU(uint x) {\n"
"    x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; x ^= x >> 16; return x;\n"
"}\n"
"inline float sgaHash(int2 cell, uint seed) {\n"
"    uint h = sgaHashU(uint(cell.x) * 0x8da6b343u ^ uint(cell.y) * 0xd8163841u ^ seed * 0xcb1ab31fu);\n"
"    return float(h & 0xffffffu) / 16777216.0;\n"
"}\n"
"inline float2 sgaHash2(int2 cell, uint seed) {\n"
"    return float2(sgaHash(cell, seed), sgaHash(cell, seed + 0x51u));\n"
"}\n"
"inline float sgaNoise(float2 p, uint seed) {\n"
"    float2 i = floor(p), f = p - i;\n"
"    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);\n"
"    int2 c = int2(i);\n"
"    float a = sgaHash(c, seed), b = sgaHash(c + int2(1, 0), seed);\n"
"    float d = sgaHash(c + int2(0, 1), seed), e = sgaHash(c + int2(1, 1), seed);\n"
"    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);\n"
"}\n"
"inline float sgaFbm(float2 p, uint seed, int octaves) {\n"
"    float sum = 0.0, amp = 0.5, norm = 0.0;\n"
"    for (int i = 0; i < octaves; i++) {\n"
"        sum += amp * sgaNoise(p, seed + uint(i) * 17u);\n"
"        norm += amp; amp *= 0.5; p = p * 2.03 + 11.7;\n"
"    }\n"
"    return sum / norm;\n"
"}\n"
"inline float sgaLuma(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }\n"
"inline float3 sgaToLinear(float3 c) {\n"
"    return select(pow((c + 0.055) / 1.055, 2.4), c / 12.92, c <= 0.04045);\n"
"}\n"
"inline float3 sgaToSRGB(float3 c) {\n"
"    c = max(c, 0.0);\n"
"    return select(1.055 * pow(c, 1.0 / 2.4) - 0.055, c * 12.92, c <= 0.0031308);\n"
"}\n"
"\n"
"struct SGFrame { float2 size; float time; float amount; };\n"
"\n"
"#define SG_BANDS 24\n"
"\n"
"struct SGHills { float2 size; float4 front; float4 back; float levels[SG_BANDS]; };\n"
"\n"
"// The two hills: for every column of the screen, the level is interpolated from the bands that stand on either\n"
"// side of it, and everything below the crest is filled with the hill's colour, thinning out toward the crest so\n"
"// a peak ends in light rather than in an edge.\n"
"static inline float sgaHill(float u, constant float *levels) {\n"
"    float at = clamp(u, 0.0, 1.0) * (SG_BANDS - 1);\n"
"    int i = int(floor(at));\n"
"    int j = min(i + 1, SG_BANDS - 1);\n"
"    return mix(levels[i], levels[j], fract(at));\n"
"}\n"
"\n"
"fragment half4 sgaHills(SGAVertex in [[stage_in]], constant SGHills &h [[buffer(0)]]) {\n"
"    // The back hill is drawn wider and taller, as the Core Animation path has it.\n"
"    float back = sgaHill(in.uv.x, h.levels) * 1.25;\n"
"    float front = sgaHill(in.uv.x, h.levels);\n"
"    float4 color = float4(0.0);\n"
"    color += h.back * smoothstep(back, back - 0.25, 1.0 - in.uv.y);\n"
"    color += h.front * smoothstep(front, front - 0.18, 1.0 - in.uv.y);\n"
"    return half4(clamp(color.rgb, 0.0, 1.0), clamp(color.a, 0.0, 1.0));\n"
"}\n"
"\n"
"// Grain, for the Fluid field's film look: pixel noise at a share of `amount`, moving with `time`.\n"
"fragment half4 sgaGrain(SGAVertex in [[stage_in]], constant SGFrame &f [[buffer(0)]]) {\n"
"    float2 px = in.uv * f.size;\n"
"    float g = sgaPixelHash(px, uint(f.time * 12.0)) - 0.5;\n"
"    return half4(half3(g * f.amount + 0.5), half(1.0));\n"
"}\n"
"\n"
"// The ambient field: the light behind Home's cards and the player in the newer build, drawn rather than moved.\n"
"// Two colours run into each other where the noise folds over, a soft light sits over it, and a little grain keeps\n"
"// it from banding on an OLED screen.\n"
"struct SGAmbientFrame { float2 size; float time; float amount; float speed; float warp; float gain; float pad;\n"
"                        float4 top; float4 bottom; };\n"
"\n"
"fragment half4 sgaAmbient(SGAVertex in [[stage_in]], constant SGAmbientFrame &a [[buffer(0)]]) {\n"
"    float aspect = a.size.x / max(a.size.y, 1.0);\n"
"    float2 uv = in.uv;\n"
"    float2 p = float2(uv.x * aspect, uv.y) * 1.7;\n"
"    float t = a.time * 0.045 * max(a.speed, 0.15);\n"
"    // The domain is folded over itself first, so the noise drifts in folds instead of sliding.\n"
"    float fold = 0.45 + a.warp;\n"
"    float2 q = p + float2(sgaFbm(p + float2(t, -t), 7u, 3), sgaFbm(p + float2(-t, t), 11u, 3)) * fold;\n"
"    float n = sgaFbm(q * 1.35 + float2(0.0, t * 0.5), 23u, 4);\n"
"    float3 color = mix(a.bottom.rgb, a.top.rgb, smoothstep(0.22, 0.78, n));\n"
"    float2 d = (uv - float2(0.5, 0.62)) * float2(aspect, 1.0);\n"
"    float light = smoothstep(1.15, 0.05, length(d));\n"
"    color += a.top.rgb * light * 0.32;\n"
"    color *= (0.62 + 0.48 * light) * a.gain;\n"
"    color += (sgaPixelHash(uv * a.size, uint(a.time * 24.0)) - 0.5) * 0.03 * a.amount;\n"
"    return half4(half3(clamp(color, 0.0, 1.0)), half(1.0));\n"
"}\n";

static SGShaderLibrary *sg_shared;
static NSArray<NSString *> *sg_why;

NSArray<NSString *> *SGShaderWhy(void) {
    [SGShaderLibrary shared];
    return sg_why;
}

@implementation SGShaderLibrary

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SGShaderLibrary *library = [SGShaderLibrary new];
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            sg_why = @[@"this device has no Metal device"];
            SGLog(@"shaders: %@", sg_why[0]);
            return;
        }
        library->_device = device;
        library->_queue = [device newCommandQueue];
        NSError *error = nil;
        library->_library = [device newLibraryWithSource:kShaderSource options:nil error:&error];
        if (!library->_library) {
            sg_why = @[@"the shaders did not compile", error.localizedDescription ?: @"no reason given"];
            SGLog(@"shaders: %@: %@", sg_why[0], sg_why[1]);
            return;
        }
        sg_shared = library;
        SGLog(@"shaders: compiled %lu functions on %@", (unsigned long)library->_library.functionNames.count, device.name);
    });
    return sg_shared;
}

@end

@interface SGGrainView () <MTKViewDelegate>
@end

// The frame the grain shader takes: the view's size in pixels, the time (a moving seed), and how much noise.
typedef struct {
    float width, height;
    float time;
    float amount;
} SGGrainUniforms;

@implementation SGGrainView {
    id<MTLRenderPipelineState> _pipeline;
    CFTimeInterval _started;
    NSTimer *_timer;
}

+ (BOOL)metalGrainAvailable {
    return SGShaderLibrary.shared != nil;
}

- (instancetype)initWithFrame:(CGRect)frame {
    SGShaderLibrary *kit = SGShaderLibrary.shared;
    if (!kit) return nil;   // a caller that got a view means this path is there: nothing half-made
    if (!(self = [super initWithFrame:frame device:kit.device])) return nil;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly = YES;
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.enableSetNeedsDisplay = NO;   // drawn by a 30 Hz timer, not by MetalKit's own display link
    self.paused = YES;
    self.delegate = self;
    _started = CACurrentMediaTime();
    _amount = 0.35;

    NSError *error = nil;
    id<MTLFunction> vertex = [kit.library newFunctionWithName:@"sgaFullscreen"];
    id<MTLFunction> fragment = [kit.library newFunctionWithName:@"sgaGrain"];
    if (vertex && fragment) {
        MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
        descriptor.vertexFunction = vertex;
        descriptor.fragmentFunction = fragment;
        descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
        // The noise is blended over what is under it; this view itself draws nothing opaque.
        MTLRenderPipelineColorAttachmentDescriptor *attachment = descriptor.colorAttachments[0];
        attachment.blendingEnabled = YES;
        attachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        attachment.sourceAlphaBlendFactor = MTLBlendFactorOne;
        attachment.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        _pipeline = [kit.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    }
    if (!_pipeline) {
        SGLog(@"shaders: the grain pipeline did not build: %@", error.localizedDescription ?: @"no reason given");
        return nil;
    }
    return self;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [_timer invalidate];
    _timer = nil;
    // A view out of a window draws nothing at all: no timer, no command buffer, no power spent.
    if (!self.window || self.hidden || _amount <= 0) return;
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 repeats:YES block:^(NSTimer *timer) {
        SGGrainView *view = weakSelf;
        if (!view.window || view.hidden || view.amount <= 0) return;
        // MetalKit lays out the pass, takes the drawable and calls -drawInMTKView:.
        [view draw];
    }];
}

- (void)dealloc {
    [_timer invalidate];
}

- (void)setAmount:(CGFloat)amount {
    _amount = fmax(0, fmin(1, amount));
    self.hidden = _amount <= 0;
}

- (void)drawInMTKView:(MTKView *)view {
    SGShaderLibrary *kit = SGShaderLibrary.shared;
    if (!kit || !_pipeline || self.hidden || !self.window || _amount <= 0) return;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    if (!drawable || !pass) return;

    // A new seed a few times a second: the grain shimmers like film rather than sitting still like a texture.
    SGGrainUniforms uniforms = {
        (float)view.drawableSize.width, (float)view.drawableSize.height,
        (float)((CACurrentMediaTime() - _started) * 24.0), (float)_amount,
    };
    id<MTLCommandBuffer> buffer = [kit.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:_pipeline];
    [encoder setFragmentBytes:&uniforms length:sizeof uniforms atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];
    [buffer presentDrawable:drawable];
    [buffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Nothing to rebuild: the shader reads the size from the uniforms each frame.
}

@end

#define SG_BANDS 24

// The frame the hills shader takes: the view's size, the two colours, and the bands, eased already.
typedef struct {
    float width, height;
    float front[4], back[4];
    float levels[SG_BANDS];
} SGHillsUniforms;

@interface SGHillsView () <MTKViewDelegate>
@end

@implementation SGHillsView {
    id<MTLRenderPipelineState> _pipeline;
    NSTimer *_timer;
    float _levels[SG_BANDS];
    BOOL _hasLevels;
}

+ (BOOL)metalHillsAvailable {
    return SGShaderLibrary.shared != nil;
}

- (instancetype)initWithFrame:(CGRect)frame {
    SGShaderLibrary *kit = SGShaderLibrary.shared;
    if (!kit) return nil;
    if (!(self = [super initWithFrame:frame device:kit.device])) return nil;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly = YES;
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.enableSetNeedsDisplay = NO;
    self.paused = YES;
    self.delegate = self;
    self.frontColor = UIColor.whiteColor;
    self.backColor = [UIColor colorWithWhite:1 alpha:0.5];
    NSError *error = nil;
    id<MTLFunction> vertex = [kit.library newFunctionWithName:@"sgaFullscreen"];
    id<MTLFunction> fragment = [kit.library newFunctionWithName:@"sgaHills"];
    if (vertex && fragment) {
        MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
        descriptor.vertexFunction = vertex;
        descriptor.fragmentFunction = fragment;
        descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
        MTLRenderPipelineColorAttachmentDescriptor *attachment = descriptor.colorAttachments[0];
        attachment.blendingEnabled = YES;
        attachment.sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        attachment.destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        _pipeline = [kit.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    }
    if (!_pipeline) {
        SGLog(@"shaders: the hills pipeline did not build: %@", error.localizedDescription ?: @"no reason given");
        return nil;
    }
    return self;
}

- (void)dealloc {
    [_timer invalidate];
}

- (void)setLevels:(const float *)levels count:(NSInteger)count {
    _hasLevels = levels != NULL;
    for (NSInteger i = 0; i < SG_BANDS; i++) _levels[i] = _hasLevels && i < count ? levels[i] : 0;
}

- (void)setMoving:(BOOL)moving {
    if (moving == _moving) return;
    _moving = moving;
    [_timer invalidate];
    _timer = nil;
    if (!moving) return;
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 repeats:YES block:^(NSTimer *timer) {
        SGHillsView *view = weakSelf;
        if (!view.window || !view.moving) return;
        [view draw];
    }];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    BOOL moving = _moving;
    _moving = !moving;   // forces setMoving to take effect again for the new window
    [self setMoving:moving];
}

- (void)drawInMTKView:(MTKView *)view {
    SGShaderLibrary *kit = SGShaderLibrary.shared;
    if (!kit || !_pipeline || !self.window || !_moving || !_hasLevels) return;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    if (!drawable || !pass) return;

    SGHillsUniforms uniforms = {0};
    uniforms.width = (float)view.drawableSize.width;
    uniforms.height = (float)view.drawableSize.height;
    CGFloat r = 0, g = 0, b = 0, a = 1;
    [self.frontColor getRed:&r green:&g blue:&b alpha:&a];
    CGFloat br = 0, bg = 0, bb = 0, ba = 1;
    [self.backColor getRed:&br green:&bg blue:&bb alpha:&ba];
    uniforms.front[0] = (float)r; uniforms.front[1] = (float)g; uniforms.front[2] = (float)b; uniforms.front[3] = (float)a;
    uniforms.back[0] = (float)br; uniforms.back[1] = (float)bg; uniforms.back[2] = (float)bb; uniforms.back[3] = (float)ba;
    memcpy(uniforms.levels, _levels, sizeof _levels);

    id<MTLCommandBuffer> buffer = [kit.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:_pipeline];
    [encoder setFragmentBytes:&uniforms length:sizeof uniforms atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];
    [buffer presentDrawable:drawable];
    [buffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    // Nothing to rebuild: the shader reads the size from the uniforms each frame.
}

@end

// The frame the ambient shader takes: the view's size, the seconds it has run, the grain, the rate and width it
// folds at, its gain, then the two colours. Laid out to the shader's own alignment -- a float2, five floats, a
// pad, then the colours on a 16-byte line.
typedef struct {
    float width, height;
    float time;
    float amount;
    float speed;
    float warp;
    float gain;
    float pad;
    float top[4], bottom[4];
} SGAmbientUniforms;

@interface SGAmbientView () <MTKViewDelegate>
@end

@implementation SGAmbientView {
    id<MTLRenderPipelineState> _pipeline;
    NSTimer *_timer;
    CFTimeInterval _started;
}

+ (BOOL)metalAmbientAvailable {
    return SGShaderLibrary.shared != nil;
}

- (instancetype)initWithFrame:(CGRect)frame {
    SGShaderLibrary *kit = SGShaderLibrary.shared;
    if (!kit) return nil;
    if (!(self = [super initWithFrame:frame device:kit.device])) return nil;
    self.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    self.framebufferOnly = YES;
    self.opaque = YES;
    self.userInteractionEnabled = NO;
    self.enableSetNeedsDisplay = NO;
    self.paused = YES;
    self.delegate = self;
    self.topColor = [UIColor colorWithWhite:1 alpha:1];
    self.bottomColor = [UIColor colorWithWhite:0 alpha:1];
    self.amount = 0.35;
    NSError *error = nil;
    id<MTLFunction> vertex = [kit.library newFunctionWithName:@"sgaFullscreen"];
    id<MTLFunction> fragment = [kit.library newFunctionWithName:@"sgaAmbient"];
    if (vertex && fragment) {
        MTLRenderPipelineDescriptor *descriptor = [MTLRenderPipelineDescriptor new];
        descriptor.vertexFunction = vertex;
        descriptor.fragmentFunction = fragment;
        descriptor.colorAttachments[0].pixelFormat = self.colorPixelFormat;
        _pipeline = [kit.device newRenderPipelineStateWithDescriptor:descriptor error:&error];
    }
    if (!_pipeline) {
        SGLog(@"shaders: the ambient pipeline did not build: %@", error.localizedDescription ?: @"no reason given");
        return nil;
    }
    _started = CACurrentMediaTime();
    return self;
}

- (void)dealloc {
    [_timer invalidate];
}

- (void)setMoving:(BOOL)moving {
    if (moving == _moving) return;
    _moving = moving;
    [_timer invalidate];
    _timer = nil;
    if (!moving) return;
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 / 30.0 repeats:YES block:^(NSTimer *timer) {
        SGAmbientView *view = weakSelf;
        if (!view.window || !view.moving) return;
        [view draw];
    }];
}

// In a window it draws once at once, then keeps drawing while it moves; out of one it stops, as the grain does.
- (void)didMoveToWindow {
    [super didMoveToWindow];
    BOOL moving = _moving;
    _moving = !moving;   // forces setMoving to take effect again for the new window
    [self setMoving:moving];
    if (self.window) [self draw];
}

- (void)drawInMTKView:(MTKView *)view {
    SGShaderLibrary *kit = SGShaderLibrary.shared;
    if (!kit || !_pipeline || !self.window) return;
    id<CAMetalDrawable> drawable = view.currentDrawable;
    MTLRenderPassDescriptor *pass = view.currentRenderPassDescriptor;
    if (!drawable || !pass) return;

    SGAmbientUniforms uniforms = {0};
    uniforms.width = (float)view.drawableSize.width;
    uniforms.height = (float)view.drawableSize.height;
    uniforms.time = (float)(CACurrentMediaTime() - _started);
    uniforms.amount = (float)self.amount;
    uniforms.speed = 1;
    uniforms.warp = 0.7;
    uniforms.gain = 1;
    // Fluid's own six numbers, read as it draws: the sliders on Adjust then move the field they name.
    if (self.followsFluid) {
        uniforms.speed = (float)(SGRFluidValue(SGRFluidSpeed) / 100.0);
        uniforms.warp = (float)(SGRFluidValue(SGRFluidWarp) / 100.0);
        CGFloat brightness = SGRFluidValue(SGRFluidBrightness) / 100.0, saturation = SGRFluidValue(SGRFluidSaturation) / 150.0;
        uniforms.gain = (float)(brightness * (0.85 + 0.15 * saturation));
        uniforms.amount = (float)(SGRFluidValue(SGRFluidGrain) / 100.0);
    }
    CGFloat r = 0, g = 0, b = 0, a = 1, br = 0, bg = 0, bb = 0, ba = 1;
    [self.topColor getRed:&r green:&g blue:&b alpha:&a];
    [self.bottomColor getRed:&br green:&bg blue:&bb alpha:&ba];
    uniforms.top[0] = (float)r; uniforms.top[1] = (float)g; uniforms.top[2] = (float)b; uniforms.top[3] = 1;
    uniforms.bottom[0] = (float)br; uniforms.bottom[1] = (float)bg; uniforms.bottom[2] = (float)bb; uniforms.bottom[3] = 1;

    id<MTLCommandBuffer> buffer = [kit.queue commandBuffer];
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:pass];
    [encoder setRenderPipelineState:_pipeline];
    [encoder setFragmentBytes:&uniforms length:sizeof uniforms atIndex:0];
    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];
    [buffer presentDrawable:drawable];
    [buffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    [self draw];
}

@end
