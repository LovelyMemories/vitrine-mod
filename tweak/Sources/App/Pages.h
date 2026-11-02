// The pages of Mod Settings that bring the layers together: what each look offers is its own
// (Shared/, Native/, Redesigned/, Flow/), and which of it a page shows is decided here, from the stored
// look (Core/SGUIMode.h), so a page opened after changing it shows what the restart will bring.
#import <UIKit/UIKit.h>

@class SGModRow;

// The look as a pick of three (Legacy, Redesigned, Flow) and what the row's ⓘ reads out. The switch the
// tour and the warning still speak in: on stores the redesign, off the legacy look.
void SGSetRedesignedUI(BOOL on);
extern NSString *const SGRedesignedUIInfo;
// Below iOS 26: what turning one of the mod's looks on risks there, for the pick's alert and the tour.
NSString *SGRedesignUntestedWarning(void);

// The look as a menu row with its ⓘ, offering to restart Spotify when it changes; below iOS 26 it warns
// first. It leads Mod Settings' main page.
SGModRow *SGRedesignedUIRow(void);
UIViewController *SGAppearancePage(void);   // the stored look's accent and AMOLED, the font and the app icon
UIViewController *SGPlayerSettingsPage(void);
UIViewController *SGLyricsSettingsPage(void);   // with Sing (Shared/Sing) on it
UIViewController *SGNavbarPage(void);       // the tab editor of whichever look is stored
