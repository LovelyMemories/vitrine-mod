// Only the music: a long press on the cover takes everything off the player but the artwork, and a long press again
// brings it back. What stays is the field behind (its clip too, when Animated artwork plays there) and the cover
// itself, with the views that hold either of them; everything else of the player's view is taken away with
// SGRPlayerVanish, which works on Spotify's Swift views, and each one's alpha and touches are kept on the view so the
// way back is exact.
//
// The recognizer goes on the artwork list, where the cover is (PlayerGestures.x hooks the same list for the double
// tap): Spotify's units are siblings of it rather than children, so a long press on a button never gets here. It has
// to win against Spotify's own taps and presses, so it is asked to recognize together with them and to consume the
// touches it ends up handling; it never fails, since the short tap is not ours to judge.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Player.h"

static char kZenAlphaKey;      // NSNumber, the alpha a view had before it was taken off
static char kZenTouchesKey;    // NSNumber, its userInteractionEnabled then
static char kZenTakenKey;      // NSNumber, so a view taken off twice keeps its first alpha
static char kZenAttachedKey;   // the recognizer, on the list
static __weak UIView *sg_zenList;
static BOOL sg_zen;
static NSHashTable<UIView *> *sg_zenHidden;   // weak: a view that goes away takes its entry with it

// The mod's own target for the recognizer: the list is Spotify's class and has no selector of ours.
@interface SGRZenPress : NSObject <UIGestureRecognizerDelegate>
- (void)longPressed:(UILongPressGestureRecognizer *)recognizer;
@end

static UIView *playerHostOf(UIView *view) {
    for (UIView *v = view; v; v = v.superview) {
        if ([v.nextResponder isKindOfClass:UIViewController.class]) return v;
    }
    return view.window;
}

// A view stays when it is the cover or the field, or holds one of them; every other one is taken off. The lyric
// preview goes with the rest: Spotify draws it in the player's own band, not inside the cover, so it is no part of
// what the long press leaves.
static BOOL prune(UIView *view, UIView *cover, UIView *field) {
    BOOL keeps = view == cover || view == field;
    for (UIView *sub in view.subviews) {
        if (prune(sub, cover, field)) keeps = YES;
    }
    if (!keeps) {
        if (!objc_getAssociatedObject(view, &kZenTakenKey)) {
            objc_setAssociatedObject(view, &kZenAlphaKey, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kZenTouchesKey, @(view.userInteractionEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kZenTakenKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (!sg_zenHidden) sg_zenHidden = [NSHashTable weakObjectsHashTable];
            [sg_zenHidden addObject:view];
        }
        SGRPlayerVanish(view);
    }
    return keeps;
}

static void applyZen(void) {
    UIView *list = sg_zenList;
    UIView *host = list ? playerHostOf(list) : nil;
    if (!host) return;
    // The list is the cover on screen and the only one the press reached; SGRPlayerCoverList is the answer when it is
    // not there yet.
    UIView *cover = list.superview ? list : (SGRPlayerCoverList() ?: list);
    prune(host, cover, (UIView *)SGRPlayerField());
    SGLog(@"player zen: the music alone in %@ of %lu views on, %lu taken off", NSStringFromClass(host.class),
          (unsigned long)host.subviews.count, (unsigned long)sg_zenHidden.count);
}

static void bringBack(void) {
    for (UIView *view in sg_zenHidden.allObjects) {
        NSNumber *alpha = objc_getAssociatedObject(view, &kZenAlphaKey);
        NSNumber *touches = objc_getAssociatedObject(view, &kZenTouchesKey);
        if (alpha) view.alpha = alpha.doubleValue;
        view.userInteractionEnabled = touches ? touches.boolValue : YES;
        view.accessibilityElementsHidden = NO;
        objc_setAssociatedObject(view, &kZenAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kZenTouchesKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kZenTakenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [sg_zenHidden removeAllObjects];
    SGLog(@"player zen: the player back");
}

static void toggleZen(void) {
    sg_zen = !sg_zen;
    if (sg_zen) {
        if (!sg_zenHidden) sg_zenHidden = [NSHashTable weakObjectsHashTable];
        applyZen();
    } else {
        bringBack();
    }
}

@implementation SGRZenPress
- (void)longPressed:(UILongPressGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) return;
    if (!SGHidden(SGRKeyPlayerZen)) {
        SGLog(@"player zen: the switch is off");
        return;
    }
    toggleZen();
}

// Spotify's tap and press recognizers on the cover would otherwise keep this one from ever reaching its 0.6 s.
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer {
    return YES;
}
@end

static SGRZenPress *sg_zenPress;

// Called from the list's layout pass: the recognizer goes on once, and while the player plays alone the pruning is
// done again, since Spotify lays out views of its own into the page as the song goes on. Switched off mid-song, the
// player comes back at the next pass rather than staying bare.
static void attachZen(UIView *list) {
    sg_zenList = list;
    if (!objc_getAssociatedObject(list, &kZenAttachedKey)) {
        if (!sg_zenPress) sg_zenPress = [SGRZenPress new];
        UILongPressGestureRecognizer *press = [[UILongPressGestureRecognizer alloc] initWithTarget:sg_zenPress
                                                                                          action:@selector(longPressed:)];
        press.minimumPressDuration = 0.45;
        press.allowableMovement = 12;
        press.delaysTouchesEnded = NO;
        press.cancelsTouchesInView = NO;
        press.delegate = sg_zenPress;
        [list addGestureRecognizer:press];
        objc_setAssociatedObject(list, &kZenAttachedKey, press, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        SGLog(@"player zen: the press is on %@", NSStringFromClass(list.class));
    }
    if (!SGHidden(SGRKeyPlayerZen)) {
        if (sg_zen) {
            sg_zen = NO;
            bringBack();
        }
        return;
    }
    if (sg_zen) applyZen();
}

%hook _TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView
- (void)layoutSubviews {
    %orig;
    attachZen((UIView *)self);
}
%end

// Spotify's single tap on the cover opens its tilt mode. With Only the music on, the cover's gesture is the long
// press, so the tap says nothing: it used to open on every try before the press had its 0.45 s. The switch off puts
// Spotify's tap back as it was.
%hook _TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView
- (void)handleTap {
    if (SGHidden(SGRKeyPlayerZen)) return;
    %orig;
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC35NowPlaying_ContentLayerPlatformImpl24AccessibleCollectionView",
                       @"_TtC35CreativeWorkCommons_CoverArtTiltKit16CoverArtTiltView"]);
}
