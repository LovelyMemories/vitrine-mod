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
#import "Shared/SpotifyPrefs/SpotifyPrefs.h"
#import "AutoMix.h"

// How long each side of the meeting lasts: the outgoing song's last seconds and the incoming song's first.
static const double kFade = 12;

static NSString *sg_lastLogged;

%hook SPTPlayerTrack

- (NSDictionary *)metadata {
    NSDictionary *metadata = %orig;
    // Diagnostics for the album page's play counts: what Spotify puts in a track's metadata, once a launch.
    static BOOL dumped;
    if (!dumped && metadata.count) {
        dumped = YES;
        SGLog(@"metadata keys: %@", [[metadata.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@", "]);
        for (NSString *key in metadata) {
            if ([key.lowercaseString containsString:@"play"] || [key.lowercaseString containsString:@"popular"]) {
                SGLog(@"metadata %@ = %@", key, metadata[key]);
            }
        }
    }
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

#pragma mark - the fade itself

// Cue points alone move nothing: they are metadata, and Spotify's core plays a crossfade only when the fade
// engine has a length and the switch is on. The 1.0.1 build does this the same way -- it sets its own length,
// keeps the user's in a key of its own, and puts it back afterwards ("Spotify's crossfade is still at AutoMix's
// length, putting back the user's own"). This is that, in its simplest form: on is one length, off is whatever
// the person had.
static NSString *const kSavedOn = @"spotifyglass.automix.crossfade.saved.on";
static NSString *const kSavedTime = @"spotifyglass.automix.crossfade.saved.ms";
static const NSInteger kAutoMixFadeMs = 12000;
static BOOL sg_applied;
static BOOL sg_wasOn;          // what the switch was before AutoMix changed it
static NSInteger sg_wasMs;

static SPTPreferences *preferences(void) {
    return SGSpotifyPreferences();
}

// Writes AutoMix's own length, keeping the person's first: a stored pair means this already happened.
static void applyCrossfade(void) {
    if (sg_applied) return;
    SPTPreferences *prefs = preferences();
    if (!prefs) return;   // not read yet: the next tick asks again
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    if ([store objectForKey:kSavedTime] == nil) {
        sg_wasOn = prefs.audioCrossfade;
        sg_wasMs = prefs.audioCrossfadeTime;
        [store setBool:sg_wasOn forKey:kSavedOn];
        [store setInteger:sg_wasMs forKey:kSavedTime];
    } else {
        sg_wasOn = [store boolForKey:kSavedOn];
        sg_wasMs = [store integerForKey:kSavedTime];
    }
    [prefs setAudioCrossfadeTime:kAutoMixFadeMs];
    [prefs setAudioCrossfade:YES];
    sg_applied = YES;
    SGLog(@"automix: Spotify's crossfade at AutoMix's length, %ld ms (the person's was %ld ms, %@)",
          (long)kAutoMixFadeMs, (long)sg_wasMs, sg_wasOn ? @"on" : @"off");
}

static void restoreCrossfade(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    if ([store objectForKey:kSavedTime] == nil) return;   // nothing was taken: nothing to put back
    SPTPreferences *prefs = preferences();
    if (!prefs) return;
    NSInteger ms = [store integerForKey:kSavedTime];
    BOOL on = [store boolForKey:kSavedOn];
    [prefs setAudioCrossfadeTime:ms];
    [prefs setAudioCrossfade:on];
    [store removeObjectForKey:kSavedTime];
    [store removeObjectForKey:kSavedOn];
    sg_applied = NO;
    SGLog(@"automix: Spotify's crossfade back to the person's (%@, %ld ms)", on ? @"on" : @"off", (long)ms);
}

%ctor {
    // The switch deciding this is read every few seconds rather than at launch: turning AutoMix off has to give
    // the crossfade back without a restart, since it changed a setting the person can see.
    if (SGEnabled(SGKeyAutoMix)) {
        [NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *tick) {
            if (!SGEnabled(SGKeyAutoMix)) {
                restoreCrossfade();
                [tick invalidate];
                return;
            }
            applyCrossfade();
        }];
        SGLog(@"automix: cue points on, %.0f s either side of the meeting", kFade);
        %init;
    }
    // Switched off since last launch, with the person's crossfade still held: given back on the next tick.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!SGEnabled(SGKeyAutoMix)) restoreCrossfade();
    });
}
