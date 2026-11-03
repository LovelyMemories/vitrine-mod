// Cue points for Spotify's own transitions, added to what the player reads about a track.
//
// The 1.0.1 build carries AutoMix by putting automix.fade_in_cuepoint.* and automix.fade_out_cuepoint.* into a
// track's metadata and switching Spotify's automix on (docs/automix-101.md). This does the second half of that
// on its own: two songs that are this app's crossfade apart get a fade out and a fade in, and Spotify's own
// transition engine plays the meeting.
//
// Off unless the switch is on, read at launch. When it is off this file installs nothing.
//
// ponytail: the cue points are placed from the track's length, not from its beat or its energy -- there is no
// analysis to place them with. That is the reason this is a switch one turns on to see, not a default.
#import "Core/SGCore.h"
#import "Shared/Player/PlayerState.h"
#import "AutoMix.h"

// How long each side of the meeting lasts: the outgoing song's last seconds and the incoming song's first.
static const double kFade = 12;

static NSString *sg_lastLogged;

%hook SPTPlayerTrack

- (NSDictionary *)metadata {
    NSDictionary *metadata = %orig;
    if (!SGEnabled(SGKeyAutoMix)) return metadata;
    NSString *uri = SGURIString(self.URI);
    if (!uri.length) return metadata;
    double duration = 0;
    id length = metadata[@"duration"];
    if ([length respondsToSelector:@selector(doubleValue)]) duration = [length doubleValue] / 1000;
    if (!(duration > 0)) return metadata;

    // Last out, first in: the outgoing song fades over its last seconds, the incoming one comes up over its
    // first, and the two cross by the window between them.
    NSMutableDictionary *edited = [metadata mutableCopy];
    [edited addEntriesFromDictionary:SGAutoMixCuePoints(uri, duration, duration - kFade, kFade)];
    if (![uri isEqualToString:sg_lastLogged]) {
        sg_lastLogged = uri;
        SGLog(@"automix: cue points on %@ (%.0f s): out at %.0f, in until %.0f", uri, duration, duration - kFade, kFade);
    }
    return edited;
}

%end

%ctor {
    if (!SGEnabled(SGKeyAutoMix)) return;
    %init;
    SGRequireClasses(@[@"SPTPlayerTrack"]);
    SGLog(@"automix: cue points on, %.0f s either side of the meeting", kFade);
}
