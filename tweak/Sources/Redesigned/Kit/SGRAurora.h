// The artwork's colors as a few soft blobs, drifting and breathing behind a page: an aurora, not a picture.
//
// Like SGRFlow.h it is Core Animation only -- radial gradients the render server composites and moves, with
// nothing drawn and nothing blurred live -- so it costs the same whether the page is still or moving.
//
// Ownership: the field that makes one owns it. Threading: main thread only.
#import <UIKit/UIKit.h>

@interface SGRauroraLayer : CALayer

// One color per blob, top to bottom of `colors`; repeated when there are fewer colors than blobs, and white at
// a low alpha when there are none. Animated crossfades the old colors out, as the field's own color does.
- (void)setColors:(NSArray<UIColor *> *)colors animated:(BOOL)animated;

// Drift and breathe, or hold still where they are. Off, the blobs stay exactly where they were: a paused song
// holds its aurora, as it holds the moving field.
@property (nonatomic) BOOL moving;
@end
