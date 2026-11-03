// The Player page's row of looks: one card per preset of the Fluid field, the chosen one ringed in the accent, the
// name under it. A tap lays that preset's six settings down at once, which is what the sliders below then show.
//
// Each card is the preset drawn small -- the same colors in the same places, softened the way the shader softens
// them -- so the choice is made by eye rather than by reading three sliders afterwards. It is a picture of a
// look, not the live field: the card is a few gradients, and the page keeps them cheap.
#import <UIKit/UIKit.h>

// `names` in the order the presets are numbered (SGRFluidPreset); the ring follows `SGRFluidCurrentPreset()`,
// re-read on every layout so a slider moved by hand drops it.
@interface SGRFluidPresetStrip : UIView
// `picked` runs with the preset's index once one is tapped.
- (instancetype)initWithFrame:(CGRect)frame names:(NSArray<NSString *> *)names picked:(void (^)(NSInteger index))picked;
// The colors the cards are drawn in: the flowing field's, from the artwork (SGRPalette's flowColors).
@property (nonatomic, copy) NSArray<UIColor *> *colors;
@end
