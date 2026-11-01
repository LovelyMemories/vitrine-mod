// The clip on disk, as the mod's moving artwork already keeps it (Shared/AnimatedArtwork): reshaped once for
// the now playing key, and kept until the cap pushes the oldest out. Nothing here goes to the network: the
// download belongs to the store the player and the album and artist headers read too.
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// The clip centre cropped to `aspect`, width over height. A clip already that shape comes back as it is.
void SGArtworkCrop(NSURL *file, NSString *identifier, CGFloat aspect, void (^done)(NSURL *cropped, NSString *note));
// The clip's first frame, which the system wants the preview still to match; NULL when unreadable.
void SGArtworkFirstFrame(NSURL *file, void (^done)(CGImageRef frame));
