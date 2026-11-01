// The tour goes up the first time Home appears, not at launch: a fresh sideload lands on the login
// screen first, and a tour over that is wrong. A moment after, so Home has drawn under the glass.
//
// There is no What's new sheet: it was this tree's and is gone (its key, spotifyglass.whatsnew.seen, is
// left behind in the preferences and read by nothing). A build that has had its tour goes straight to Home,
// whatever version it is.
#import "Core/SGCore.h"
#import "Onboarding.h"

%hook _TtC19Home_FunkisPageImpl20FunkisViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (SGFlag(SGKeyOnboardingSeen, NO)) return;
            SGLog(@"onboarding: home appeared, the tour was not seen, showing it");
            SGShowOnboarding();
        });
    });
}
%end

%ctor {
    SGCheckEnvironmentOnce();
    if (SGFlag(SGKeyOnboardingSeen, NO)) return;
    %init;
    SGRequireClasses(@[@"_TtC19Home_FunkisPageImpl20FunkisViewController"]);
}
