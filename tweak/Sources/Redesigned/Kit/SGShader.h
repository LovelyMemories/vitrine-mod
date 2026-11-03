// Metal for the player's backgrounds: the shaders behind the visuals Core Animation cannot do well.
//
// Metal is not in the tweak's build: there is no .metal target, and a .metal file would need its own Theos rule.
// So the shaders are Metal source text, compiled once at runtime with -newLibraryWithSource:error: -- a few tens
// of milliseconds on the first frame, nothing to the build. Everything here answers nil rather than throwing when
// a device cannot do it, and the caller falls back to the Core Animation background it had.
//
// Threading: main thread only. Compiling happens once.
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface SGShaderLibrary : NSObject
// The device's library and queue, or nil on a device without Metal (none this mod runs on, but the fallback is
// cheap). nil `reason`-free: it also sets SGShaderWhy().
+ (instancetype)shared;
// Where it is nil, why, in a log line's worth of words; nil when the library is in.
NSArray<NSString *> *SGShaderWhy(void);
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLCommandQueue> queue;
@property (nonatomic, readonly) id<MTLLibrary> library;
@end

// Grain as the shader draws it, over whatever is under it: the Metal answer to the tile SGRFluid lays down. It is
// a view rather than a layer so it can be put over any background without touching it, and it draws nothing at
// all -- not even a frame -- while it is invisible, out of a window, or `amount` is 0.
@interface SGGrainView : MTKView
// 0 to 1. Where the shader library is missing, this view answers +metalGrainAvailable NO and never appears.
@property (nonatomic) CGFloat amount;
+ (BOOL)metalGrainAvailable;
@end

// The Visualizer's hills, on Metal: the spectrum as a crest drawn per pixel rather than as a path the app builds
// every frame. The bands come in already eased, so the shader only draws the two hills and the glow.
//
// Same ground rules as the grain: it draws only while it is in a window and `moving`, and it answers NO from
// +metalHillsAvailable where the library is missing, so PlayerVisualiser.m keeps its Core Animation path.
@interface SGHillsView : MTKView
+ (BOOL)metalHillsAvailable;
// `count` levels, 0 to 1 from the foot to the top of the view; nil while the song sends nothing.
- (void)setLevels:(const float *)levels count:(NSInteger)count;
// The front hill's colour; the back one is derived from it, dimmer.
@property (nonatomic, strong) UIColor *frontColor;
@property (nonatomic, strong) UIColor *backColor;
// Drawing at all: a paused song sets it NO and the timer stops with it.
@property (nonatomic) BOOL moving;
@end
