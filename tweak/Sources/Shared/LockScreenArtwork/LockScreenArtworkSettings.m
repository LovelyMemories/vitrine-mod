// The Lock screen page of Mod Settings (App/ModSettings.x links it from the root, under either look) and the
// rows it holds. The sources are fixed, Spotify's Canvas first and Apple Music's cover after it: the order page
// upstream has in Settings/SGOrderPage.h is not in this tree yet.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "LockScreenArtwork.h"

static void sayWhatIsMissing(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:SGLocalized(@"Animated lock screen")
        message:[NSString stringWithFormat:SGLocalized(@"Animated artwork is the lock screen's own, and iOS takes one only from 26 on. This phone runs iOS %@, where the cover stays still."), UIDevice.currentDevice.systemVersion]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [SGTopController() presentViewController:alert animated:YES completion:nil];
}

NSArray<SGModRow *> *SGAnimatedArtworkRows(void) {
    if (!SGAnimatedArtworkAvailable())
        return @[SGStatActionRow(@"Animated lock screen", nil, ^NSString *{ return @"Needs iOS 26"; }, ^{ sayWhatIsMissing(); })];
    return @[
        SGSwitchRow(@"Animated lock screen", @"The track's Canvas, else Apple Music's animated cover, behind the lock screen's controls",
                    SGKeyAnimatedLockArtwork),
    ];
}

// The page: what the system draws on the lock screen. Its own settings, not the player's: they hold under
// either look, and a switch here needs no restart, the next track's clip being read then.
UIViewController *SGLockScreenPage(void) {
    return [[SGModPage alloc] initWithTitle:@"Lock screen" intro:nil sections:@[
        SGSection(nil, SGAnimatedArtworkRows()),
    ] footer:nil];
}
