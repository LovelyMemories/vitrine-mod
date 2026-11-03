#import "SGShader.h"
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
"// Grain, for the Fluid field's film look: pixel noise at a share of `amount`, the same each frame when time is\n"
"// held still, which is a paused song.\n"
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
