// Flow's waveform: the song's own shape, built as it plays.
//
// The player's progress line is Spotify's slider, and it stays Spotify's: Flow lays this view over it and
// makes the slider's own track and thumb transparent, so the drag, the seeking and the accessibility are
// still its own and only the picture changes.
//
// The bars are not decoration and not a guess. The spectrum the player already taps (Core/SGSpectrum.h) is
// turned into a loudness several times a second and kept in the bar the song is passing at that moment, so
// the part already heard fills with the shape it really had; the rest stays a flat line until it is reached.
// A seek does not invent bars the song never played: what is behind the jump keeps the shape it got.
// Threading: main thread only, but for the render thread's hand-off inside the spectrum.
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Core/SGSpectrum.h"
#import "Flow/Kit/SGFColor.h"

@interface SGFWaveformView : UIView
// Where the song is, 0 to 1, and how long it is in seconds (0 while unknown): the bar the loudness lands in,
// and the share of the row drawn as heard.
- (void)setShare:(CGFloat)share seconds:(CGFloat)seconds;
@end
