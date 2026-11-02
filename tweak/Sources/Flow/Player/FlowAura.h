// Flow's Aura mode, the view a player's band can hold. See FlowAura.m.
#import <UIKit/UIKit.h>

@interface SGFAuraView : UIView
// The playing track's artwork, drawn smaller than the player's own cover; nil until one has been read.
@property (nonatomic, strong) UIImage *artwork;
@end
