// The title of a page of the mod's, drawn the way the screenshots have it: a large title at the leading edge with a
// round × at the trailing one, over the page's own content, inside the page's background.
//
// The bar itself is the system's and stays (the back button on a pushed page, the close on a presented one): only
// the title's view is replaced, so a swipe back, VoiceOver's title and the safe-area layout are all unchanged.
#import <UIKit/UIKit.h>

// Puts the title and the close on `page`, once. Safe to call on every pass of its layout.
void SGPageShowLargeTitle(UIViewController *page);
