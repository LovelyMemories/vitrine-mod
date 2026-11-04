// The accent colour as a strip of dots: Spotify's own green, Apple Music's red, the redesign's green and the five
// colours the picker offers, one tap each. The dot in effect is ringed in white. A colour picked anywhere else --
// the picker under the row below -- reads here too, since the strip asks the stored value every time it is drawn.
#import <UIKit/UIKit.h>

UIView *SGRAccentStrip(void);
