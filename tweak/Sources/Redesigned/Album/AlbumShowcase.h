// The Albums page's card: an album's page drawn small -- the cover under the title and its artist, the album's own
// three buttons, its tracks with their lengths, a line of its notes and the shelf of further albums by the artist
// under them. It is a picture of the page, not the page: no live data, no touches, and the same on every album, so
// the switches below are read against something rather than against nothing.
#import <UIKit/UIKit.h>

@interface SGRAlbumShowcase : UIView
// The cover shown in the card; nil draws the placeholder slate.
@property (nonatomic, strong) UIImage *artwork;
@end
