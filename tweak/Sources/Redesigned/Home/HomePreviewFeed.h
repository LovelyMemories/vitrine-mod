// Home's feed as the mod's own card shows it: what the cards on Home actually carry -- the picture each one draws
// and the words under it -- so the card on the Home page of Mod Settings is the Home that is on screen rather than
// a drawing of one.
//
// The feed is remembered from the tiles the redesign styles (SGRHomeStyleTile, called for every tile Home makes),
// by walking up to the collection view they sit in. Nothing is kept of Spotify's views: the items are pictures and
// strings, read again each time the card asks.
//
// Threading: main thread only.
#import <UIKit/UIKit.h>

@interface SGRHomeFeedItem : NSObject
@property (nonatomic, strong) UIImage *image;   // nil when the card draws none yet
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@end

// Called with any view of Home's; remembers the feed it belongs to. Safe to call often.
void SGRHomeFeedRemember(UIView *viewOfHome);

// Up to `most` of the cards Home shows now, in the order it shows them: a picture and a line or two. Empty when
// Home is not on screen, which is the card's cue to fall back to its own drawing.
NSArray<SGRHomeFeedItem *> *SGRHomeFeedItems(NSInteger most);
