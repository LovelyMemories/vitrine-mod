// The banner under the mod's pages while settings that wait for a launch have been changed: "2 changes need a
// restart", with a Restart button that closes Spotify so the next start brings them in. It is a glass pill floating
// over the page's own content, over the tab bar, and it goes away by itself when the count is back to none (a page
// can put a switch back), or with the restart.
//
// The count is this launch's: a setting changed and changed back still counts, since what the page reads and what
// the app is running are two different things.
//
// Threading: main thread only.
#import <UIKit/UIKit.h>

// One more setting that waits for a launch. Called by SGModPage for a switch on a page that says so.
void SGRRestartChanged(void);
// How many so far this launch.
NSInteger SGRRestartChangeCount(void);

// The pill, in `host` (a page's own view): put there once, brought up to date from then on.
void SGRRestartBannerAttach(UIView *host);
