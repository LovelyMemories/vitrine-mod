// The player's backgrounds as cards rather than as a row of words, the way the newer build picks one: each card
// shows the current cover the way that background draws it -- still, blurred, in the fluid's folds, as hills -- with
// its name under it, and the one in effect carries the accent's ring. A tap picks it.
//
// The previews are drawn in Core Animation over the cover the player is showing: no Metal, no live field, just
// enough of each look to tell them apart at a card's size.
#import <UIKit/UIKit.h>

@interface SGRPlayerBackgroundStrip : UIView
// `names` in SGRPlayerBackgroundKind's order; `picked` runs with the index tapped.
- (instancetype)initWithFrame:(CGRect)frame names:(NSArray<NSString *> *)names picked:(void (^)(NSInteger index))picked;
// The cover the previews are drawn from; the placeholder is drawn until it is set.
@property (nonatomic, strong) UIImage *artwork;
- (void)setSelected:(NSInteger)selected;
@end
