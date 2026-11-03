// The Albums page's card: what an album's page looks like under the switches below, drawn small -- the cover, a
// line of the album's facts, and a shelf of further albums by the same artist. It is a picture of the page, not
// the page: no live data, no touches, and the same on every album, so the switches are read against something
// rather than against nothing.
#import <UIKit/UIKit.h>

@interface SGRAlbumShowcase : UIView
// The cover shown in the card; nil draws the placeholder slate.
@property (nonatomic, strong) UIImage *artwork;
@end
