// The home screen icon: a strip of the alternates the IPA carries, each drawn as a preview, the one iOS is on
// ringed in the accent. A tap switches, and the strip reads the choice back from iOS rather than from settings,
// since iOS is what keeps it.
//
// The row above the strip counts the alternates and opens the full list, for there to be one when the strip is not
// enough. Both are built here and the Appearance page places them.
#import <UIKit/UIKit.h>

@class SGModRow;

// The strip: a horizontal run of icons in order (Default first), `selected` the accent ring. Nil when the IPA
// carries no alternate icon, or when this device does not take one.
UIView *SGAppIconStrip(void);
// The row under it: "All icons", with how many there are.
SGModRow *SGAppIconCountRow(void);
