// The turning rainbow ring the Mod Settings switches wear (Settings/SGGlowSwitch.m), for the views of the
// redesign that carry it: the Home header's pill and the Search header's avatar. Two bands of the same conic
// gradient, the line itself and a narrow faint one under it turning the other way so the light moves against the
// line; each is masked to the outline by a holder of its own, since a mask on the turning layer would turn with it.
#import <UIKit/UIKit.h>

// Puts the ring on `rect` in `host`'s coordinates, round its `radius` corners, and keeps it there: created once
// per `key` per host, brought to the front, and its geometry updated on every call. Main thread only.
void SGRRingApply(UIView *host, const void *key, CGRect rect, CGFloat radius);
