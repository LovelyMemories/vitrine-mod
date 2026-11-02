#import <UIKit/UIKit.h>
#import "SGUIMode.h"
#import "SGLog.h"
#import "SGPrefs.h"

BOOL SGRedesignAvailable(void) {
    if (@available(iOS 26.0, *)) return YES;
    return NO;
}

static NSString *const kStarting = @"spotifyglass.redesign.untested.starting";
static const NSTimeInterval kStarted = 15;
static BOOL sg_fellBack;

BOOL SGRedesignFellBack(void) {
    return sg_fellBack;
}

// Below iOS 26 a launch with the mod's look leaves a mark that the main queue takes off once it has run
// for a while, or as Spotify first leaves the front, which only a main thread that answers is told of. A
// launch that hung (the watchdog of #37) gets to neither, so the next one finds the mark and starts
// native. ponytail: a force quit from the switcher in the first 15 s, with Spotify still in front until
// then, counts as a hang; a hang later on is not caught.
static BOOL startsUntested(void) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    if ([store boolForKey:kStarting]) {
        [store removeObjectForKey:kStarting];
        SGSetInt(SGKeyLook, SGUILookNative);
        SGSetEnabled(SGKeyRedesignUntested, NO);
        sg_fellBack = YES;
        SGLog(@"ui: the last launch with a look of the mod's on iOS %@ did not get going, so this one is native",
              NSProcessInfo.processInfo.operatingSystemVersionString);
        return NO;
    }
    [store setBool:YES forKey:kStarting];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kStarted * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [store removeObjectForKey:kStarting];
    });
    __block id token = [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:nil
                                                                  usingBlock:^(NSNotification *note) {
        [NSNotificationCenter.defaultCenter removeObserver:token];
        [store removeObjectForKey:kStarting];
    }];
    return YES;
}

SGUILook SGUILookStored(void) {
    // The one switch per look is moved onto the look, once, the first time this is asked. The move writes
    // straight to the defaults, past the read-through memo (SGPrefs.m), which is dropped after it.
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        BOOL moved = [NSUserDefaults.standardUserDefaults objectForKey:SGKeyRedesign] != nil;
        SGMigrateKey(SGKeyRedesign, SGKeyLook);
        if (moved) SGPrefsChanged();
    });
    // A fresh install comes up in the redesign, as it did; Reset all settings (SGKeyStock), which sweeps by
    // prefix, leaves no look stored and so comes up native.
    NSInteger fallback = SGFlag(SGKeyStock, NO) ? SGUILookNative : SGUILookRedesigned;
    NSInteger value = SGInt(SGKeyLook, fallback);
    if (value < SGUILookNative || value > SGUILookFlow) value = SGUILookRedesigned;
    SGUILook look = (SGUILook)value;
    // Below 26 both of the mod's looks count only with the warning accepted (SGRedesignedUI's comment).
    if (look != SGUILookNative && !SGRedesignAvailable() && !SGFlag(SGKeyRedesignUntested, NO)) look = SGUILookNative;
    return look;
}

void SGSetUILook(SGUILook look) {
    SGSetInt(SGKeyLook, look);
    SGSetEnabled(SGKeyRedesignUntested, look != SGUILookNative && !SGRedesignAvailable());
}

static SGUILook sg_launch;
static dispatch_once_t sg_launchOnce;

static SGUILook launchLook(void) {
    dispatch_once(&sg_launchOnce, ^{
        SGUILook stored = SGUILookStored();
        if (stored == SGUILookNative) sg_launch = SGUILookNative;
        else if (SGRedesignAvailable() || startsUntested()) sg_launch = stored;
        else sg_launch = SGUILookNative;
        NSString *names[] = {@"native", @"redesigned", @"flow"};
        SGLog(@"ui: %@%@", names[sg_launch],
              SGRedesignAvailable() ? @"" : sg_launch == SGUILookNative ? @" (the mod's looks need iOS 26)" : @" (untested below iOS 26)");
    });
    return sg_launch;
}

BOOL SGRedesignedUI(void) {
    return launchLook() != SGUILookNative;
}

BOOL SGFlowUI(void) {
    return launchLook() == SGUILookFlow;
}

BOOL SGFlowUIStored(void) {
    return SGUILookStored() == SGUILookFlow;
}

BOOL SGNativeUI(void) {
    return launchLook() == SGUILookNative;
}

BOOL SGRedesignedUIStored(void) {
    return SGUILookStored() != SGUILookNative;
}
