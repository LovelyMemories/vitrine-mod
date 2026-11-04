// The accent colour as a strip of dots: Spotify's own green, Apple Music's red, the redesign's green and the five
// colours the picker offers, one tap each. The dot in effect is ringed in white. A colour picked anywhere else --
// the picker under the row below -- reads here too, since the strip asks the stored value every time it is drawn.
#import <UIKit/UIKit.h>

UIView *SGRAccentStrip(void);

// The newer build's picker keeps the colours you have been using ("accent color saved recent swatches"): the strip
// shows them beside its own. Called with every colour picked anywhere, the picker row included.
void SGRAccentRemember(NSInteger rgb);
