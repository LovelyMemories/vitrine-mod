// AutoMix: Apple Music's transition planner, asked about a pair of songs.
//
// The planner is not Apple Music's audio engine. It answers where an incoming song should come in, on which
// beat, and how much it has to be stretched -- a schedule, in a small JSON document. Blending the two songs is
// still Spotify's own crossfade; the plan only says when and how long.
//
// The planner itself is a Swift helper beside the tweak (SpotifyGlassAutoMix26.dylib on iOS 26, and
// SpotifyGlassAutoMix.dylib below it), linked against Apple's private SonicKit framework. It is loaded at
// runtime, never linked, so a system without that framework simply has no planner: SGAutoMixAvailable()
// answers NO and the mod falls back to Spotify's plain crossfade. docs/automix-sonickit.md has the whole of it.
//
// Threading: any thread. Loading happens once.
#import <Foundation/Foundation.h>

// Off until turned on: how this behaves is still being found out (docs/automix-101.md), and an unset switch is
// off, so nothing changes for anyone who has not asked. Read at launch, as every switch of the mod's is.
#define SGKeyAutoMix @"spotifyglass.automix"

// YES once the helper is loaded and answers to SGAutoMixPlan.
BOOL SGAutoMixAvailable(void);

// Asks the planner for a transition from `outgoing` to `incoming`. Both carry what the planner takes: at least
// "id" and "duration", and optionally the analysis it uses when it is there.
//
// Answers the planner's own JSON (an NSString of what the helper returned), or nil when there is no helper or it
// answered nothing. What the keys are is the helper's business; this side parses none of them yet.
// `criteria` may be nil for the planner's defaults.
NSString *SGAutoMixPlanForSongs(NSDictionary *outgoing, NSDictionary *incoming, NSDictionary *criteria);

// What Spotify's player reads about a transition: the cue points a track's metadata may carry. The names are
// the ones the 1.0.1 build writes (docs/automix-101.md); whether 9.1.90 reads them is what trying this is for.
//
// Every transition fades the outgoing song out over its last `fade` seconds and the incoming one in over its
// first `fade`, so the two meet in the middle and cross by roughly the window.
NSDictionary<NSString *, NSString *> *SGAutoMixCuePoints(NSString *uri, double duration,
                                                         double fadeOutStart, double fadeInEnd);
