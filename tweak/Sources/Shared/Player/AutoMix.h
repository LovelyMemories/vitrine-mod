// Auto mix: Spotify's Automix, the blended transitions between songs it keeps for Premium. The server answers a
// Free account without the two flags the player reads for it, and the mod answers them itself, the way it forces a
// Premium account's flags elsewhere (Shared/AdBlock/Premium.m). It draws no screen of its own, so it answers under
// either look, and it holds from launch like every other switch.
#import <UIKit/UIKit.h>

#define SGKeyAutoMix @"spotifyglass.automix"

@class SGModRow;
// The row on the Premium, ads & privacy page.
SGModRow *SGAutoMixRow(void);
