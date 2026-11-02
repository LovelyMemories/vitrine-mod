// The artwork's colors as curtains of light over black -- bright at their foot, thinning upward, their sides
// soft, each drifting a little and changing hue where it stands -- behind a page. An aurora, not a picture.
//
// The black base is the point: the field paints its own color under everything, and light on a colored wash
// has no depth. The hue drift is two colors to a curtain whose opacities cross, so nothing is re-rendered.
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
