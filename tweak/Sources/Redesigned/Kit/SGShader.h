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
