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

// YES once the helper is loaded and answers to SGAutoMixPlan.
BOOL SGAutoMixAvailable(void);

// Asks the planner for a transition from `outgoing` to `incoming`. Both carry what the planner takes: at least
// "id" and "duration", and optionally the analysis it uses when it is there.
//
// Answers the planner's own JSON (an NSString of what the helper returned), or nil when there is no helper or it
// answered nothing. What the keys are is the helper's business; this side parses none of them yet.
// `criteria` may be nil for the planner's defaults.
NSString *SGAutoMixPlanForSongs(NSDictionary *outgoing, NSDictionary *incoming, NSDictionary *criteria);
