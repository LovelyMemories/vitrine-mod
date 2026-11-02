// Where Spotify's own player puts things, and how to keep its cover out of the way: declared here, in
// Core, because both of the mod's players draw over the same screen (Redesigned/Player/PlayerArtwork.x
// defines them) and neither look may import the other. AGENTS.md's rule for that is a function declared
// low and defined high, which these are.
//
// Everything answers CGRectNull until the player has laid out once, and again once it is closing: a caller
// that draws into one of these must be ready for nothing to draw at all.
#import <UIKit/UIKit.h>

// The band the player gives its artwork, between the header row and the title, in `host`'s coordinates.
CGRect SGRPlayerArtworkAreaIn(UIView *host);
// The cover on screen as it is drawn, its paused shrink included, in `host`'s coordinates.
CGRect SGRPlayerCoverFrameIn(UIView *host);
// The scale the cover is drawn at: 1 while playing, its shrink while paused.
CGFloat SGRPlayerCoverScale(void);
// Hides the cover on screen and its shadow, or shows them again, for a view of the mod's to stand in.
void SGRPlayerSetCoverHidden(BOOL hidden);

// The playing track's artwork as the mod last read it, in `trackURI` and `identity` if given; nil until it
// has one. Defined by Redesigned/Kit/SGRBridges.x and declared here so Flow can draw the cover itself.
UIImage *SGRNowPlayingArtwork(NSString **trackURI, NSString **identity);
