// Flow's colors: black through, lit by the cover's own. A song's artwork gives two of them -- a deep wash
// for the field behind a mode, and a bright one for its strokes, its badge and the line being sung -- and
// a cover too gray to give either falls back to the mod's accent, as Follow the cover does in the redesign.
//
// Flow keeps its own copy rather than the redesign's palette (AGENTS.md: each look its own), so a change
// to one look's color cannot move the other's.
// Threading: main thread only.
#import <UIKit/UIKit.h>

// The black every Flow screen sits on (#09090B).
UIColor *SGFBlack(void);
// The cover's color as a field's wash, or SGFAccent() when the cover is gray. Never nil.
UIColor *SGFWashForImage(UIImage *image);
// The same color bright enough to draw a stroke in on top of that wash. Never nil.
UIColor *SGFGlowForImage(UIImage *image);
// What Flow lights when the cover has no color of its own: the accent Mod Settings stores for it, else the
// accent mark the mod draws on a dark card.
UIColor *SGFAccent(void);
