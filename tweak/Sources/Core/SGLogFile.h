// The mod's own lines, kept on the phone: every SGLog line is also appended to a file under the app's Application
// Support, so a log that only went to the system's can be read and sent from the Crash logs page after the app has
// been closed, without FLEX and without a cable.
//
// A line may come from Core Audio's render thread (Music Haptics, tempo), so nothing here waits on the disk: the
// write is queued on a serial queue of its own. The file is rolled over at a few megabytes, and the one before it
// is kept, so the folder cannot grow without bound.
#import <Foundation/Foundation.h>

// Appends `line` with its time, from any thread. Cheap: the disk work is queued.
void SGLogFileWrite(NSString *line);
// The log files that exist, newest first: the live one, then the one before it.
NSArray<NSString *> *SGLogFilePaths(void);
void SGLogFileDeleteAll(void);
