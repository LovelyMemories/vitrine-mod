// The accent that follows the cover, as the newer build offers it ("Accent from the cover"): while the switch is on,
// the colour in effect is taken from the cover of the song playing -- the dominant colour the palette finds -- and
// put back to the one you picked when it goes off.
//
// Nothing is kept of the derived colour: the switch on means the colour is the cover's, so it is worked out again on
// every new cover. The custom colour stays where it was, untouched, which is what the switch returns to.
//
// Threading: the artwork notification arrives on whatever thread set it; the palette reads off the main thread and
// hands back on it, so only the first hop is dispatched.
#import "Core/SGCore.h"
#import "SGRKit.h"
#import "SGRAccent.h"

static NSInteger rgbOf(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) return SGInt(SGRKeyAccent, SGRDefaultAccent);
    return ((NSInteger)lround(r * 255) << 16) | ((NSInteger)lround(g * 255) << 8) | (NSInteger)lround(b * 255);
}

static void follow(void) {
    if (!SGEnabled(SGRKeyAccentFromCover)) return;
    UIImage *image = SGRNowPlayingArtwork(NULL, NULL);
    if (!image) return;
    [SGRPalette tintForImage:image surface:[UIColor colorWithWhite:0.08 alpha:1] completion:^(UIColor *tint) {
        if (!tint || !SGEnabled(SGRKeyAccentFromCover)) return;
        NSInteger rgb = rgbOf(tint);
        if (rgb != SGInt(SGRKeyAccent, SGRDefaultAccent)) SGSetInt(SGRKeyAccent, rgb);
    }];
}

// One observer for the launch, made once the dyld has the mod in: the cover changes whenever a song does.
__attribute__((constructor)) static void SGRAccentCoverStart(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter addObserverForName:SGRNowPlayingArtworkDidChangeNotification object:nil queue:nil
                                                    usingBlock:^(NSNotification *note) {
            dispatch_async(dispatch_get_main_queue(), ^{ follow(); });
        }];
        follow();
    });
}

// The switch, off and on: off puts the colour you picked back.
void SGRAccentFromCoverSet(BOOL on) {
    SGSetEnabled(SGRKeyAccentFromCover, on);
    if (on) { follow(); return; }
    SGSetInt(SGRKeyAccent, SGInt(SGRKeyAccentCustom, SGRDefaultAccent));
}
