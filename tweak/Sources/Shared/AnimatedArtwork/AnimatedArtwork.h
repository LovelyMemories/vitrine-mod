// Moving artwork for a track: its Canvas, or Apple Music's animated album cover where the album has one.
// SGMotionCatalog.m looks covers and logos up in Apple Music's catalog. SGMotionStore.m keeps every video
// as a local file.
//
// This is the player's and the Album and Artist headers' (Redesigned/Player/PlayerMotion.x and the like).
// The lock screen's full-screen artwork, the lyrics a line at a time and the star were this file's too and
// are gone: the system draws the lock screen's animated artwork instead, from Shared/LockScreenArtwork.
#import <UIKit/UIKit.h>

// Off until switched on: download in Low Data Mode too.
#define SGKeyMotionLowData @"spotifyglass.motion.lowdata"

typedef NS_ENUM(NSInteger, SGMotionShape) {
    SGMotionSquare,   // 1:1
    SGMotionTall,     // 3:4
};

// Apple Music's animated cover for an album, as a local file, or nil. `done` runs on the main queue.
// `pixels` is the width it is shown at; the closest stream at or above it is downloaded.
void SGMotionAlbumCover(NSString *artist, NSString *album, SGMotionShape shape, CGFloat pixels,
                        void (^done)(NSURL *file));

// The artist's logo from Apple Music, a transparent PNG `pixels` wide, or nil. Main queue.
void SGMotionArtistLogo(NSString *artist, CGFloat pixels, void (^done)(UIImage *logo));

// The width a full-screen clip is downloaded at: three quarters of the screen's pixels. A tall cover at the
// screen's full width ran to 29 MB a song; at this width it was 7 MB and looks the same in motion.
CGFloat SGMotionPixels(void);

// Apple Music's catalog songs with this ISRC, each with its isrc, durationInMillis and hasHaptics, or nil
// when the catalog could not be asked. Kept for the launch. Main queue.
void SGMotionSongsWithISRC(NSString *isrc, void (^done)(NSArray *songs));

// Apple Music's cover for the recording with this ISRC, a square `pixels` wide, or nil when the catalog has no
// song for it or could not be asked. Main queue.
void SGMotionArtworkWithISRC(NSString *isrc, CGFloat pixels, void (^done)(NSURL *artwork));

// Where moving artwork comes from (MotionSources.m): the keys that are on, in the order they are asked,
// Spotify's Canvas then Apple Music's animated cover unless the user changed it.
#define SGKeyMotionSources @"spotifyglass.motion.sources"
NSArray<NSString *> *SGMotionSourceOrder(void);
BOOL SGMotionAppleMusicOn(void);
// The track's Canvas video as its metadata names it (canvas.url, of a canvas.type that is a video), or nil.
NSURL *SGMotionCanvasIn(NSDictionary *metadata);
// The first clip the order finds for the track `uri`, as a local file, or nil, and the key of the source it
// came from. `canvas` is the track's Canvas video, nil when its metadata names none, and then Spotify's
// Canvas service is asked for it. Main queue.
void SGMotionClipFor(NSString *uri, NSURL *canvas, NSString *artist, NSString *album, SGMotionShape shape, CGFloat pixels,
                     void (^done)(NSURL *file, NSString *source));

// Follows the player for one user of moving artwork, the lock screen or the redesign's player
// (SGMotionFollower.m). Each track's sources are walked once, and again when its Canvas turns up in a later
// state, as it does on a skip, where Spotify reports the track before its extended metadata, unless the clip
// showing came from a source above Canvas. `begin` runs as a walk starts, to take the last clip off, and
// says whether to walk at all; `found` gets the walk's clip, nil for none, and never runs for a walk a newer
// one overtook. Once a walk has ended, the next track's clip is fetched ahead. Main queue.
@class SPTPlayerState;
@interface SGMotionFollower : NSObject
- (instancetype)initWithBegin:(BOOL (^)(NSString *uri, SPTPlayerState *state))begin
                        found:(void (^)(NSString *uri, NSURL *file))found;
// The track is walked again from the player's last state: a setting it depends on changed.
- (void)restart;
@end
// The row that opens the ordered list, for the Player page and the lock screen's.
@class SGModRow;
SGModRow *SGMotionSourcesRow(void);

// Any remote video (a Canvas) as a local file, or nil. Main queue.
void SGMotionFile(NSURL *remote, void (^done)(NSURL *file));
// Where a video the mod makes itself is kept under `key`, among the downloads, which are kept to the
// newest few. Whether it is there yet is the caller's to check. Any thread.
NSURL *SGMotionMadeFile(NSString *key);

// The first frame of a local video. Main queue.
void SGMotionPoster(NSURL *file, void (^done)(UIImage *poster));

// Pure steps, for the harness.
NSString *SGMotionNameKey(NSString *name);
NSString *SGMotionSearchName(NSString *name);
NSString *SGMotionStreamIn(NSString *master, CGFloat pixels);
NSString *SGMotionWholeFileIn(NSString *media);
