// Apple Music's cover on the lock screen, drawn the way the redesign's player draws one: the cover filling the
// picture, dissolving at the bottom into the color the cover is made of. The system draws what
// MPNowPlayingInfoCenter carries, and the card it draws keeps the picture's own share and fits it into its box, so
// the picture is a square: the biggest one that box takes, and the cover in it without a band of color under.
//
// The recording playing is looked up in Apple Music's catalog by its ISRC (SGMotionSongsWithISRC,
// Shared/AnimatedArtwork, whose request now asks for the artwork too) and that picture is put in place of
// Spotify's. Where the catalog has no song for it, or cannot be asked, nothing is put in and Spotify's own cover
// stays: this only ever adds a picture, never removes one. The finished picture is kept in memory by ISRC, so
// going back to a song does not download or draw it again; each track's ask carries a revision, so a newer
// track's answer never lands on an older one.
#import <MediaPlayer/MediaPlayer.h>
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/Haptics/Haptics.h"
#import "Shared/Player/NowPlayingExtras.h"
#import "Shared/Player/PlayerState.h"
#import "AppleCover.h"

// Whose extras these are, in NowPlayingExtras: another feature's keys (a local file's artwork, an ISRC) are
// their own and stay.
static NSString *const kOwner = @"appleCover";

static NSCache<NSString *, UIImage *> *sg_covers;
static id sg_follower;

// A square, the screen's width across: the lock screen's card keeps the picture's own share and fits it into
// its box, so a square is the biggest picture it can be given (a taller one came out narrower, and 3:4 left the
// card with a band under it).
static CGSize canvasSize(void) {
    CGRect bounds = UIScreen.mainScreen.bounds;
    CGFloat scale = UIScreen.mainScreen.scale ?: 3;
    CGFloat side = MIN(round(bounds.size.width * scale), 1290);
    return CGSizeMake(side, side);
}

static CGColorSpaceRef sRGB(void) {
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); });
    return space;
}

// The picture under the cover: the color it is made of, read off a one-pixel draw of it.
static UIColor *fieldColor(UIImage *cover) {
    unsigned char pixel[4] = {0};
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, sRGB(), (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    if (!context) return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), cover.CGImage);
    CGContextRelease(context);
    // Lifted a little, as the player lifts its field off a dark cover, so the seam is not two blacks.
    return [UIColor colorWithRed:MIN(1, pixel[0] / 255.0 * 1.15 + 0.02)
                           green:MIN(1, pixel[1] / 255.0 * 1.15 + 0.02)
                            blue:MIN(1, pixel[2] / 255.0 * 1.15 + 0.02) alpha:1];
}

// The cover filling the screen, its last stretch dissolving into the color it is made of.
static UIImage *composite(UIImage *cover, CGSize size) {
    if (cover.size.width < 1 || cover.size.height < 1 || size.width < 1 || size.height < 1) return nil;
    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.opaque = YES;
    format.scale = 1;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef ctx = context.CGContext;
        UIColor *field = fieldColor(cover) ?: UIColor.blackColor;
        [field setFill];
        UIRectFill(CGRectMake(0, 0, size.width, size.height));
        // Filled, so a square cover's sides go rather than a band of color appearing at one.
        CGFloat scale = MAX(size.width / cover.size.width, size.height / cover.size.height);
        CGSize drawn = CGSizeMake(cover.size.width * scale, cover.size.height * scale);
        [cover drawInRect:CGRectMake((size.width - drawn.width) / 2, (size.height - drawn.height) / 2, drawn.width, drawn.height)];
        // The fade, over the last of the picture: clear at the top of the band, the field's color at the bottom,
        // and the color below it, so the clock and the player over it read on the darker part.
        CGFloat band = round(size.height * 0.22);
        CGFloat r = 0, g = 0, b = 0, a = 1;
        [field getRed:&r green:&g blue:&b alpha:&a];
        CGColorRef clear = CGColorCreate(sRGB(), (CGFloat[]){r, g, b, 0});
        CGColorRef solid = CGColorCreate(sRGB(), (CGFloat[]){r, g, b, 1});
        CGGradientRef fade = CGGradientCreateWithColors(sRGB(), (__bridge CFArrayRef)@[(__bridge id)clear, (__bridge id)solid], NULL);
        CGContextDrawLinearGradient(ctx, fade, CGPointMake(0, size.height - band), CGPointMake(0, size.height),
                                    kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(fade);
        CGColorRelease(clear);
        CGColorRelease(solid);
    }];
}

@interface SGAppleCoverFollower : NSObject <SGPlayerStateObserver>
@end

@implementation SGAppleCoverFollower {
    NSString *_uri;
    NSUInteger _revision;
}

// The picture goes in when it is drawn, so the now playing info is not rewritten twice for one track.
- (void)publish:(UIImage *)image title:(NSString *)title revision:(NSUInteger)revision {
    if (revision != _revision || !image) return;
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:image.size
                                                                 requestHandler:^UIImage *(CGSize size) { return image; }];
    SGNowPlayingSetExtras(kOwner, @{MPMediaItemPropertyArtwork: artwork}, title);
}

// Every answer already asked for is dropped, and the picture taken off: Spotify's cover is what is left.
- (void)forget {
    _uri = nil;
    _revision++;
    SGNowPlayingSetExtras(kOwner, nil, nil);
}

- (void)refollow {
    [self forget];
    [self playerStateDidReport:SGPlayerState()];
}

- (void)playerStateDidReport:(SPTPlayerState *)state {
    // The screen's size and the now playing info are the main thread's: a report from another one comes here.
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self playerStateDidReport:state]; });
        return;
    }
    if (!SGFlag(SGKeyAppleCover, YES)) {
        [self forget];
        return;
    }
    NSString *uri = SGURIString(state.track.URI);
    if (!uri.length || uri == _uri || [uri isEqualToString:_uri]) return;
    _uri = uri;
    // The last track's picture goes at once: the lock screen shows Spotify's until ours is here.
    SGNowPlayingSetExtras(kOwner, nil, nil);
    NSString *title = state.track.trackTitle;
    if (!title.length) return;
    NSUInteger revision = ++_revision;
    CGSize size = canvasSize();
    SGSpotifyISRC(uri, 1, ^(NSString *isrc) {
        if (revision != self->_revision || !isrc.length) return;
        UIImage *known = [sg_covers objectForKey:isrc];
        if (known) {
            [self publish:known title:title revision:revision];
            return;
        }
        SGMotionArtworkWithISRC(isrc, MIN(MAX(size.width, size.height), 2000), ^(NSURL *remote) {
            if (revision != self->_revision || !remote) return;
            [[NSURLSession.sharedSession dataTaskWithURL:remote completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                UIImage *cover = data.length ? [UIImage imageWithData:data] : nil;
                UIImage *picture = cover ? composite(cover, size) : nil;
                if (!picture) return;
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (revision != self->_revision) return;
                    [sg_covers setObject:picture forKey:isrc];
                    [self publish:picture title:title revision:revision];
                });
            }] resume];
        });
    });
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
}

@end

void SGAppleCoverRefresh(void) {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ SGAppleCoverRefresh(); });
        return;
    }
    [sg_follower refollow];
}

%ctor {
    sg_covers = [NSCache new];
    sg_covers.countLimit = 12;
    SGAppleCoverFollower *follower = [SGAppleCoverFollower new];
    sg_follower = follower;
    SGAddPlayerStateObserver(follower);
}
