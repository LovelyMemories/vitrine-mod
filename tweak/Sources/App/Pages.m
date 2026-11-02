#import "Core/SGCore.h"
#import "Core/SGFlow.h"
#import "Shared/AppIcon/AppIcon.h"
#import "Shared/Fonts/Fonts.h"
#import "Shared/LyricsTranslation/LyricsTranslation.h"
#import "Redesigned/Player/Player.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Pages.h"
#import "Shared/ArtistBlock/ArtistBlock.h"
#import "Shared/Gestures/Gestures.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Shared/LyricsMeanings/Meanings.h"
#import "Shared/Player/PlayerSettings.h"
#import "Shared/AppleCover/AppleCover.h"
#import "Native/Appearance/Appearance.h"
#import "Native/Navbar/Navbar.h"
#import "Native/NowPlayingBar/NowPlayingBar.h"
#import "Native/Player/NowPlaying.h"
#import "Shared/Lossless/SGLossless.h"
#import "Redesigned/Lyrics/LyricsText.h"
#import "Redesigned/Lyrics/LyricsLook.h"
#import "Redesigned/Navbar/Navbar.h"
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Redesigned/Kit/SGRAccent.h"

NSString *const SGRedesignedUIInfo = @"Vitrine's own screens, in one of two ways. Redesigned is the Liquid Glass look: Spotify's screens restyled, in Apple Music's spirit. Flow takes the same screens further: black throughout, lit by the cover's color, with a player of its own.\n\nNeither is compatible with the legacy look's settings. The legacy look gives you more freedom, yet still looks like Spotify.";

static NSArray<NSString *> *lookNames(void) {
    return @[@"Legacy", @"Redesigned", @"Flow"];
}

static NSArray<NSString *> *lookNotes(void) {
    return @[@"Spotify's own screens, with Vitrine's tweaks on them.",
             @"Vitrine's Liquid Glass redesign of Spotify's screens.",
             @"The redesign taken further: black, the cover's color, and a player of its own."];
}

// Below iOS 26 the mod's looks also need SGKeyRedesignUntested (Core/SGUIMode.h): whoever stores one has
// shown the warning (SGUILookStored counts them only then). Turning it off takes that back, so turning it
// on again warns again.
void SGSetRedesignedUI(BOOL on) {
    SGSetUILook(on ? (SGUILookStored() == SGUILookFlow ? SGUILookFlow : SGUILookRedesigned) : SGUILookNative);
}

NSString *SGRedesignUntestedWarning(void) {
    return [NSString stringWithFormat:@"The redesign is built on iOS 26's Liquid Glass. iOS %@ draws a blur in its place, and nobody has tested the redesign there: pages can be laid out wrongly, and Spotify can freeze as it starts. If Spotify does not start with it, the next launch goes back to Legacy.",
            UIDevice.currentDevice.systemVersion];
}

// The whole look changes hands at launch, so the pick asks for the restart straight away rather than
// leaving Spotify half in the old look.
static void offerRestart(SGUILook look) {
    NSString *message = look == SGUILookNative
        ? @"Spotify's own look comes back when Spotify starts again. Spotify closes now; open it again to see it."
        : [NSString stringWithFormat:@"%@ takes over when Spotify starts again. Spotify closes now; open it again to see it.", lookNames()[look]];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restart Spotify"
        message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { SGRestartSpotify(); }]];
    [SGTopController() presentViewController:alert animated:YES completion:nil];
}

// Below iOS 26 one of the mod's looks is stored only once its warning has been accepted, which restarts
// Spotify at once, so the pick never reads on for a look that is not coming.
static void applyLook(SGUILook look) {
    if (look == SGUILookStored()) return;
    if (look != SGUILookNative && !SGRedesignAvailable()) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Turn on %@?", lookNames()[look]]
            message:[SGRedesignUntestedWarning() stringByAppendingString:@"\n\nSpotify restarts to turn it on."]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Turn On and Restart" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            SGSetUILook(look);
            SGRestartSpotify();
        }]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
        return;
    }
    SGSetUILook(look);
    offerRestart(look);
}

SGModRow *SGRedesignedUIRow(void) {
    SGModRow *row = SGMenuRow(@"Look", lookNames(), ^NSString *{
        return lookNames()[SGUILookStored()];
    }, ^(NSInteger index) {
        applyLook((SGUILook)index);
    });
    row.subtitle = @"Restarts Spotify";
    row.glows = YES;
    row.info = SGRedesignedUIInfo;
    row.choiceNotes = lookNotes();
    return SGWithTile(row, @"sparkles", UIColor.systemIndigoColor);
}

// The stored look's own rows, then the font and the app icon, which work under either look on any iOS.
// Redesigned UI itself leads Mod Settings' main page; the language is on that page, under All flags.
UIViewController *SGAppearancePage(void) {
    NSMutableArray<SGModRow *> *everywhere = [NSMutableArray arrayWithArray:SGAppFontRows()];
    SGModRow *icon = SGAppIconRow();
    if (icon) [everywhere addObject:icon];
    return [[SGModPage alloc] initWithTitle:@"Appearance" intro:SGRestartNote sections:@[
        SGSection(nil, SGRedesignedUIStored() ? SGRAppearanceRows() : SGNativeAppearanceRows()),
        SGSection(nil, everywhere),
    ] footer:nil];
}

UIViewController *SGNavbarPage(void) {
    return SGRedesignedUIStored() ? SGRNavbarSettingsPage() : SGNavbarSettingsPage();
}

// Pronunciation, romanized lines, translation, word sweeping and line meanings exist only in the redesign's lyrics view.
static UIViewController *lyricsPage(void) {
    BOOL redesigned = SGRedesignedUIStored();
    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObjects:SGLyricsSourcesSection(redesigned), nil];
    SGModSection *timing = SGNotedSection(@"Timing", @[SGLyricsDelayRow()],
        @"Every line shows this much later than the song, for Bluetooth headphones that play a little behind the lyrics. Applies at once.");
    if (redesigned) {
        [sections addObjectsFromArray:@[
            SGSection(@"Display", @[SGRLyricsTextSizesRow(), SGLyricsWordTimingRow(), SGLyricsRomanisedRow(),
                SGSwitchRow(@"Hide the controls", @"A few seconds after the last touch, the lyrics take the whole player", SGRKeyLyricsAutoHide),
                SGSwitchRow(@"Landscape lyrics", @"Turn the phone with the lyrics open", SGRKeyLyricsLandscape)]),
            timing,
            SGSection(@"Translation", [[[@[SGLyricsTranslationLanguageRow(), SGTranslateEverySongRow()] arrayByAddingObjectsFromArray:SGOnDeviceTranslatorRows()]
                                          arrayByAddingObjectsFromArray:SGAITranslatorRows()] arrayByAddingObject:SGSavedTranslationsRow()]),
            SGSection(nil, @[SGLyricsMeaningsRow()]),
        ]];
    } else {
        [sections addObject:timing];
        // The glass lyrics button is Spotify's own lyrics page only.
        [sections addObject:SGSection(nil, @[SGGlassLyricsRow()])];
    }
    // The redesign's page leads with its lyrics playing in the look the page sets, and that look's presets.
    if (redesigned) return SGRLyricsSettingsPage(@"Lyrics", @"The look applies at once. The settings below apply after you restart Spotify.", sections);
    return [[SGModPage alloc] initWithTitle:@"Lyrics" intro:SGRestartNote sections:sections footer:nil];
}

// Lyrics has its own row on Mod Settings' main page.
UIViewController *SGLyricsSettingsPage(void) {
    return lyricsPage();
}

UIViewController *SGPlayerSettingsPage(void) {
    SGModRow *blocked = SGPageRow(@"Blocked artists", ^UIViewController *{ return SGArtistBlockSettingsPage(); });
    blocked.value = ^NSString *{
        return SGFlag(SGKeyArtistBlock, NO) ? @(SGBlockedArtists().count).stringValue : @"Off";
    };
    BOOL native = !SGRedesignedUIStored();

    // AirPods gestures, the lock screen widget and Vibrations have rows of their own on Mod Settings' main page.
    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObject:SGSection(nil, @[
        SGWithTile(SGPageRow(@"Gestures", ^UIViewController *{ return SGGesturesSettingsPage(); }), @"hand.tap", UIColor.systemBlueColor),
        SGWithTile(blocked, @"person.crop.circle.badge.xmark", UIColor.systemRedColor),
    ])];

    // Flow's player: which of its three modes the band opens in. Flow only -- the redesign has no band, and
    // the background picker below it still chooses what sits behind that band.
    if (SGFlowUIStored()) {
        [sections insertObject:SGSection(nil, @[
            SGChoiceRow(@"Flow player", @"What the band of the player shows", SGFKeyPlayerMode, SGFPlayerModeNames(), 0),
        ]) atIndex:0];
    }

    // Apple Music's cover in the system's now playing, on until switched off (Shared/AppleCover).
    SGModRow *covers = SGSwitchRow(@"Apple Music covers", @"Its cover for the song on the lock screen, Control Center and CarPlay", SGKeyAppleCover);
    covers.changed = ^(BOOL on) { SGAppleCoverRefresh(); };
    [sections addObject:SGSection(nil, @[covers])];
    if (native) {
        [sections addObject:SGSection(nil, @[
            SGWithTile(SGPageRow(@"Now playing bar", ^UIViewController *{ return SGNowPlayingBarSettingsPage(); }), @"rectangle.bottomthird.inset.filled", UIColor.systemPinkColor),
            SGWithTile(SGPageRow(@"Queue & devices", ^UIViewController *{ return SGQueueSettingsPage(); }), @"text.line.first.and.arrowtriangle.forward", UIColor.systemIndigoColor),
        ])];
        [sections addObjectsFromArray:SGNativePlayerScreenSections()];
    }
    // Switch to video is the same chip of Spotify's player under either look.
    [sections addObject:SGSection(native ? nil : @"Hide on the player", @[
        SGHideRow(@"Switch to video", @"The chip over the title of a song with a music video", SGKeyHideVideoSwitch),
    ])];

    [sections addObject:SGNotedSection(@"Lossless", @[
        SGOptionRow(@"Lossless files", @"Your own FLACs in place of Spotify's stream", SGKeyLossless),
    ], @"Put FLAC or ALAC files in Files › Spotify › Lossless. A file plays when its title and length match the song "
       @"and its sound matches what Spotify plays, from about 4 s after the song starts or you seek. Spotify still "
       @"streams its own copy, at its lowest quality while the next song has a file. Karaoke and speeds other than "
       @"1x keep Spotify's sound. Applies after you restart Spotify.")];

    // The redesign's page leads with a card of its player and the background's control, the background's
    // rows and the Mini player section under it.
    if (!native) return SGRPlayerSettingsPage(sections);
    return [[SGModPage alloc] initWithTitle:@"Player" intro:SGRestartNote sections:sections footer:nil];
}
