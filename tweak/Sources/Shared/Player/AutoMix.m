#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "AutoMix.h"

// The two flags the player reads for blended transitions: the core's own gate, and the one the app's playback
// settings are drawn from. Both are in a Premium account's configuration and left out of a Free one's.
static NSString *const kAutoMixCore = @"core-automix.automix_enabled";
static NSString *const kAutoMixSettings = @"ios-feature-settings.automix_enabled";

static id forcedAutoMix(NSString *key) {
    if (!SGHidden(SGKeyAutoMix)) return nil;
    if (![key isEqualToString:kAutoMixCore] && ![key isEqualToString:kAutoMixSettings]) return nil;
    // Said once: this line is the proof that the provider asks the mod for the flag at all, which is the first
    // thing to look for when a forced flag seems to do nothing.
    static BOOL logged;
    if (!logged) {
        logged = YES;
        SGLog(@"automix: %@ answered on", key);
    }
    return @YES;
}

// A plain .m has no Logos %ctor: the registration runs as the dylib loads, before Spotify asks for a flag.
__attribute__((constructor)) static void SGAutoMixInstall(void) {
    // It beats an override from the All flags page: the switch is the one source of this, and its row on that page
    // reads the value out locked.
    SGRegisterFlagForcer(YES, ^id(NSString *key) { return forcedAutoMix(key); },
                              ^id(NSString *key) { return forcedAutoMix(key); });
}

SGModRow *SGAutoMixRow(void) {
    SGModRow *row = SGOptionRow(@"Auto mix", @"Blended transitions between songs, the way Spotify's Automix plays "
                                             @"them. Read at launch, like every switch here", SGKeyAutoMix);
    return SGWithSymbol(row, @"arrow.triangle.merge");
}
