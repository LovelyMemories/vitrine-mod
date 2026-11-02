// Flow's player: the redesign's player kept whole -- its title, progress and controls are still Spotify's
// -- with the band it gives the cover taken over by one mode at a time.
//
//     FlowPlayerPanel.m   the band, its switch and the content of each mode
//     FlowAura.m          the line being sung, in the room the cover leaves
//     FlowBside.m         the model's voice and rest, metered
//     FlowSynesthesia.m   the spectrum as a row of bars
//     FlowPlayer.x        the panel put on the player and laid out with it
//
// Aura is the band as Spotify draws it -- the cover, with Flow's light behind it -- and the three lines
// go only in the room the cover leaves under it (FlowAura.m).
//
// Flow holds the redesign's player files off with SGFlowUI() where the two would draw the same band
// (PlayerLyrics.x's overlay comes first), so only one of them is ever in it.
// Threading: main thread only.
#import <UIKit/UIKit.h>
#import "Core/SGFlow.h"

typedef NS_ENUM(NSInteger, SGFPlayerMode) {
    SGFPlayerModeAura = 0,          // the cover Spotify draws, over the color Flow puts behind it
    SGFPlayerModeBside = 1,         // the model's voice and rest, mixed and metered (FlowBside.m)
    SGFPlayerModeSynesthesia = 2,   // the song's spectrum as a row of bars (FlowSynesthesia.m)
};

NSArray<NSString *> *SGFPlayerModeNames(void);
// The band, made on first ask in the player's `host`; nil while the player has not laid out.
UIView *SGFPlayerPanelIn(UIView *host);
// Puts it in the room the player gives its cover and lays its switch out; called on every pass of the
// player's layout. Cheap when nothing moved.
void SGFPlayerPanelLayout(UIView *host);
