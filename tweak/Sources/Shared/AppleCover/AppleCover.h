// Apple Music's cover in the system's now playing — the lock screen's full-screen artwork, Control Center and
// CarPlay — in place of Spotify's, by the recording's ISRC. On until switched off; where Apple Music has no
// song for the recording, Spotify's cover stays.
#import <Foundation/Foundation.h>

#define SGKeyAppleCover @"spotifyglass.appleCover"

// The switch was flipped: the cover goes now (off) or is fetched for the track playing now (on).
void SGAppleCoverRefresh(void);
