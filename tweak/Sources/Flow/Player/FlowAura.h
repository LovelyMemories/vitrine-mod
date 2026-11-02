// Flow's Aura mode, the view a player's band can hold. See FlowAura.m.
#import <UIKit/UIKit.h>

@interface SGFAuraView : UIView
// Where Spotify's cover is, in this view's coordinates. Aura draws only under it, and nowhere when it
// fills the band.
@property (nonatomic) CGRect coverFrame;
@end
