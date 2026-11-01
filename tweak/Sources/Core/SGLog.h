#import <Foundation/Foundation.h>
#import <os/log.h>
#import "SGLogFile.h"

// %{public}s so idevicesyslog on the Mac sees the text instead of <private>. Every line also goes to the phone's
// own file (SGLogFile.h), which the Crash logs page lists and shares, so a log outlives the closed app.
#if SG_DRIVER
// A build with the phone driver (FLEX builds, SG_DRIVER in tweak/Makefile) also keeps the last lines in
// memory, for the driver's log and wait commands (Diagnostics/Driver.m).
#define SGLog(fmt, ...) do { \
    NSString *sg_log_line_ = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[spotifyglass] %{public}s", sg_log_line_.UTF8String); \
    SGLogRemember(sg_log_line_); \
    SGLogFileWrite(sg_log_line_); \
} while (0)
void SGLogRemember(NSString *line);
// The remembered lines numbered after `after`, oldest first, each {seq, t (seconds since 1970), text}.
NSArray<NSDictionary *> *SGLogRecent(uint64_t after);
uint64_t SGLogLastSeq(void);
#else
#define SGLog(fmt, ...) do { \
    NSString *sg_log_line_ = [NSString stringWithFormat:(fmt), ##__VA_ARGS__]; \
    os_log_with_type(OS_LOG_DEFAULT, OS_LOG_TYPE_DEFAULT, "[spotifyglass] %{public}s", sg_log_line_.UTF8String); \
    SGLogFileWrite(sg_log_line_); \
} while (0)
#endif

// Long dumps, split into numbered parts under the unified log's size cap.
void SGLogLong(NSString *tag, NSString *text);
// Logs every class of the list that this Spotify does not have; a feature calls it from its %ctor.
void SGRequireClasses(NSArray<NSString *> *names);
