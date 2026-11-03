// Asked once at launch so a device log says, in one line, whether a planner is beside the tweak at all: the
// helper is loaded at runtime and never linked, so this is the only cheap way to tell "absent" from "broken".
#import "Core/SGCore.h"
#import "AutoMix.h"

%ctor {
    SGAutoMixAvailable();
}
