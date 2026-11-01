// Onboarding: a welcome page over Home the first time this build runs, in glass: Vitrine's logo landing,
// then a pick between the redesign (offered first on iOS 26) and Spotify's own look, a No ads switch that
// turns Hide ads, Hide upsells and Spoof Premium on together (off leaves them alone), pointers to what people
// miss in Mod Settings (Split Tabs, Lyrics, AirPods gestures and the Live Activity), and a line on holding
// Home for Mod Settings. The look and those switches are read at launch, so a changed pick ends the
// welcome in a restart. The Mod page offers the tour again. There is no What's new sheet: it was this
// tree's and is gone, so a launch of a new version goes straight to Home.
#import <UIKit/UIKit.h>

#define SGKeyOnboardingSeen @"spotifyglass.onboarding.seen"

// Presents the tour over the top of the app; does nothing while it is already up.
void SGShowOnboarding(void);
// The tour holds the screen; other sheets wait for it (App/About).
BOOL SGOnboardingShowing(void);

// Environment.m: what about the install can work against the mod. Said once per install state, a few
// seconds after Spotify comes up and behind the tour and the signing sheet, and kept as
// warning rows at the top of Mod Settings while it lasts.
// The Spotify versions Vitrine knows. Supported ones are tested as long as the one it is made for, which comes
// first and whose flag table it reads. Likely ones ran cleanly in a short test. Neither gets the install
// warning, and About notes "likely works" after the second. A new version goes in one list, and the warning's
// text and About follow.
#define SGSpotifyMadeFor @"9.1.78"
#define SGSpotifySupportedVersions @[SGSpotifyMadeFor, @"9.1.88", @"9.1.90", @"9.1.94"]
#define SGSpotifyLikelyWorksVersions @[]
@class SGModRow;
// SGEeveeSpotifyInjected() is Shared/Lyrics/Lyrics.h's.
NSString *SGSpotifyVersion(void);
NSArray<SGModRow *> *SGEnvironmentWarningRows(void);
void SGCheckEnvironmentOnce(void);

// The tour's prominent glass button.
UIButton *SGOnboardingButton(NSString *title);
