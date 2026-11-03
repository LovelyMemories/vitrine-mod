#import "SGShader.h"
#import <string.h>
#import "Core/SGCore.h"

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
"static inline float sgaHash(float2 p, uint seed) {\n"
"    uint h = uint(p.x) * 1597334677u ^ uint(p.y) * 3812015801u ^ seed * 2654435761u;\n"
"    h ^= h >> 13; h *= 0x5bd1e995u; h ^= h >> 15;\n"
"    return float(h & 0xFFFFu) / 65535.0;\n"
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
"    float g = sgaHash(px, uint(f.time * 12.0)) - 0.5;\n"
"    return half4(half3(g * f.amount + 0.5), half(1.0));\n"
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

@end
