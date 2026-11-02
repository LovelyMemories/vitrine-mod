// Flow's player, seen from outside Flow: the mode it opens in and the names of the modes. Declared in
// Core because App/ builds the row that picks one (Mod Settings' Player page) while Flow/ defines them,
// and neither imports the other (AGENTS.md: a function declared low and defined high).
#import <Foundation/Foundation.h>

// The mode, stored as the index of SGFPlayerMode (Aura, B-Side, Synesthesia). Read by the band when it is
// made (Flow/Player/FlowPlayerPanel.m), so a change shows the next time the player opens.
#define SGFKeyPlayerMode @"spotifyglass.flow.player.mode"

// The modes' names in the person's language, in that same order.
NSArray<NSString *> *SGFPlayerModeNames(void);

// Flow's player keeps its own foot: the redesign's volume row stays out of it. Defined in
// Flow/Player/FlowPlayerPanel.m, asked by Redesigned/Player/PlayerVolume.m.
BOOL SGFPlayerHidesVolume(void);
