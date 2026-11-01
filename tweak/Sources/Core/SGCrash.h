// The mod's own crash reports, for the builds that cannot be debugged on a Mac: an uncaught exception or a
// fatal signal writes the reason and the faulting thread's stack into Application Support/Vitrine/Crashes,
// and the last few files are offered on the Crash logs page to share. A launch that ends cleanly takes its
// own file away, so what is left is a crash.
#import <Foundation/Foundation.h>

// Newest first; empty when nothing has crashed.
NSArray<NSString *> *SGCrashReportPaths(void);
void SGCrashDeleteAll(void);
