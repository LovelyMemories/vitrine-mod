// The Animated lock screen rows (Shared/Player/PlayerSettings.m puts them on the Player page).
// The sources are fixed, Spotify's Canvas first and Apple Music's cover after it: the order page upstream
// has in Settings/SGOrderPage.h is not in this tree yet.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "LockScreenArtwork.h"

static void sayWhatIsMissing(void) {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Animated lock screen"
        message:[NSString stringWithFormat:@"Animated artwork is the lock screen's own, and iOS takes one only from 26 on. This phone runs iOS %@, where the cover stays still.", UIDevice.currentDevice.systemVersion]
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
