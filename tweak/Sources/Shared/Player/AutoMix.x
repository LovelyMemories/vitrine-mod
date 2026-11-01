// Spotify's own Automix switch, the one its playback settings page writes: SPTPreferencesImplementation carries
// audioAutomix beside audioCrossfade (Shared/AdBlock/Crossfade.x hooks the crossfade one the same way). The flags
// only draw the row and let the core build the feature; this is what the player reads to decide whether the next
// track is blended, and it is off on a Free account whatever the flags say.
//
// The %hook comes before the %ctor: Logos writes a group's class lookups where its first %hook is, and a %ctor
// above it is compiled without them (the build failed on _logos_superclass being undeclared).
#import "Core/SGCore.h"
#import "AutoMix.h"

%hook _TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation
- (BOOL)audioAutomix {
    return YES;
}

- (void)setAudioAutomix:(BOOL)on {
    // Nothing Spotify's own page does can turn it back off while the mod's switch is on.
    %orig(YES);
}
%end

%ctor {
    if (!SGHidden(SGKeyAutoMix)) return;
    %init;
    SGRequireClasses(@[@"_TtC31Preferences_CorePreferencesImpl28SPTPreferencesImplementation"]);
    SGLog(@"automix: the player's own switch is on with the mod's");
}
