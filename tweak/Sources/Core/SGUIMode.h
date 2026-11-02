// Which of the three looks runs: Spotify's own screens with the mod's tweaks on them (Native/), the
// redesign (Redesigned/), or Flow (Flow/), the redesign's own screens taken further: black throughout, lit
// by the cover's color, with a player of its own. Picked by Look at the top of Mod Settings. What does not
// draw on Spotify's screens (Shared/) runs under all three. The switch is read once, the first time
// anything asks, so the hooks, the flags and the pages see one answer for the whole launch and a change
// waits for the restart.
//
// Every hook file of Native/ starts its %ctor with `if (!SGNativeUI()) return;`, every one of
// Redesigned/ with `if (!SGRedesignedUI()) return;`, every one of Flow/ with `if (!SGFlowUI()) return;`.
//
// Flow is built on the redesign rather than beside it: until it has a screen of its own, the redesign's
// runs, so SGRedesignedUI() answers YES under Flow too and Redesigned/ needs no change. A screen Flow
// takes over is kept out by its own `SGFlowUI()` check where the two would both draw (the player's
// Redesigned/Player/ files), and the rest of Redesigned/ stays where it is.
// Threading: safe from any thread.
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SGUILook) {
    SGUILookNative = 0,      // Spotify's own screens, the mod's tweaks on them (Native/)
    SGUILookRedesigned = 1,  // the Liquid Glass redesign (Redesigned/)
    SGUILookFlow = 2,        // Flow: the redesign's screens in Flow's own language, from the player (Flow/)
};

// One switch, three values. Before it there was a switch per look's being on (SGKeyRedesign): SGMigrateKey
// moves it here at launch, YES reading 1 (the redesign) and NO 0 (native).
#define SGKeyLook @"spotifyglass.look"
// Read only by that move now; nothing writes it.
#define SGKeyRedesign @"spotifyglass.redesign"

// The stored look rather than the launch's (below iOS 26, with the warning accepted), for settings pages
// opened after it was changed: they show what the restart will bring. It is also what SGSetUILook,
// App/Pages.m's pick and the tour write.
SGUILook SGUILookStored(void);
void SGSetUILook(SGUILook look);

// Flow is the look, and its screens draw: Redesigned/Player/'s are held off where they would double it.
BOOL SGFlowUI(void);
BOOL SGFlowUIStored(void);

// The redesign is Liquid Glass, and Liquid Glass is UIGlassEffect, which the system renders and which
// no older OS can be given. Below iOS 26 the glass calls in Core/SGGlass.m and Redesigned/Kit/SGRGlass.m
// fall back to a blur, and the redesign runs untested against an older UIKit (issue #37, iOS 17: a
// scene-update watchdog hang). So below 26 it runs only after a warning has been accepted, which stores
// SGKeyRedesignUntested (SGSetUILook below does it), and only while it starts: a launch
// whose main queue neither ran for 15 s nor saw Spotify leave the front is followed by one in the native
// look, with the look back at native and SGRedesignFellBack() answering YES for the App layer to say so.
#define SGKeyRedesignUntested @"spotifyglass.redesign.untested"

// Whether this OS has the mod's looks at all: iOS 26 and up.
BOOL SGRedesignAvailable(void);
// The mod's look was on below iOS 26, and the last launch with it did not get going: this one is native.
BOOL SGRedesignFellBack(void);

// Whether the mod's own screens run at all: the redesign's, and so Flow's too, which shares them.
BOOL SGRedesignedUI(void);
BOOL SGNativeUI(void);
// The same, from the stored look rather than the launch's, for settings pages.
BOOL SGRedesignedUIStored(void);
