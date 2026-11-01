// Crash reports, written from the crash itself: the handler only touches a file descriptor opened at launch,
// writes with write(2) and the thread's frames with backtrace_symbols_fd, all of which are safe to call from a
// signal handler. Anything more (Objective-C, the file manager) is done at launch or for an uncaught
// exception, where the app is still running normally.
#import "SGCrash.h"
#import "SGLog.h"
#import <UIKit/UIKit.h>
#import <execinfo.h>
#import <signal.h>
#import <limits.h>
#import <string.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>

static char sg_pending[PATH_MAX];   // this launch's file, taken away by a clean exit
static int sg_pendingFD = -1;

static NSString *crashDirectory(void) {
    static NSString *directory;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
        directory = [support stringByAppendingPathComponent:@"Vitrine/Crashes"];
        [NSFileManager.defaultManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    });
    return directory;
}

static NSArray<NSString *> *allReports(void) {
    NSArray<NSString *> *names = [NSFileManager.defaultManager contentsOfDirectoryAtPath:crashDirectory() error:nil];
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSString *name in names) {
        if (![name hasSuffix:@".txt"]) continue;
        // This launch's own file: it is a crash only if the launch does not end, and it is taken away then.
        if ([name hasPrefix:@"pending-"]) continue;
        [paths addObject:[crashDirectory() stringByAppendingPathComponent:name]];
    }
    return [paths sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        return [b compare:a];   // the names start with the time, so the newest sorts first
    }];
}

NSArray<NSString *> *SGCrashReportPaths(void) {
    return allReports();
}

void SGCrashDeleteAll(void) {
    for (NSString *path in allReports()) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

static void writeAll(int fd, const char *text) {
    if (fd < 0 || !text) return;
    size_t left = strlen(text);
    while (left > 0) {
        ssize_t wrote = write(fd, text, left);
        if (wrote <= 0) return;
        text += wrote;
        left -= (size_t)wrote;
    }
}

// Only the faulting thread's frames, named through dyld's own table: no allocation, no Objective-C.
static void writeFrames(int fd) {
    void *frames[96];
    int count = backtrace(frames, 96);
    backtrace_symbols_fd(frames, count, fd);
}

static void exceptionHandler(NSException *exception) {
    NSMutableString *report = [NSMutableString stringWithFormat:@"Vitrine %@ on Spotify %@\niOS %@, %@\n\nUncaught exception at %@\nname: %@\nreason: %@\n\n",
                               NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"?",
                               NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"?",
                               NSProcessInfo.processInfo.operatingSystemVersionString, NSProcessInfo.processInfo.hostName, NSDate.date,
                               exception.name, exception.reason];
    for (NSString *line in exception.callStackSymbols) [report appendFormat:@"%@\n", line];
    [report writeToFile:[NSString stringWithUTF8String:sg_pending] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    SGLog(@"crash: %@ — %@", exception.name, exception.reason);
}

static void crashSignal(int number) {
    const char *name = number == SIGABRT ? "SIGABRT" : number == SIGSEGV ? "SIGSEGV" : number == SIGBUS ? "SIGBUS"
                     : number == SIGILL ? "SIGILL" : number == SIGFPE ? "SIGFPE" : number == SIGTRAP ? "SIGTRAP" : "signal";
    writeAll(sg_pendingFD, "\nfatal ");
    writeAll(sg_pendingFD, name);
    writeAll(sg_pendingFD, "\n");
    writeFrames(sg_pendingFD);
    fsync(sg_pendingFD);
    // The system's own report is made only if the signal runs its course.
    signal(number, SIG_DFL);
    raise(number);
}

// A "pending" file left by an earlier launch is a crash: that launch never took it away at a clean exit.
// This one renames it, which needs the file manager and so cannot be done from the handler itself.
static void adoptAbandoned(void) {
    NSFileManager *files = NSFileManager.defaultManager;
    for (NSString *name in [files contentsOfDirectoryAtPath:crashDirectory() error:nil]) {
        if (![name hasPrefix:@"pending-"] || ![name hasSuffix:@".txt"]) continue;
        NSString *from = [crashDirectory() stringByAppendingPathComponent:name];
        NSString *to = [crashDirectory() stringByAppendingPathComponent:
                        [name stringByReplacingOccurrencesOfString:@"pending-" withString:@"crash-"]];
        [files moveItemAtPath:from toPath:to error:nil];
    }
}

// Keep the newest few, so a crash loop cannot fill the phone.
static void prune(void) {
    NSArray<NSString *> *paths = allReports();
    for (NSUInteger i = 5; i < paths.count; i++) [NSFileManager.defaultManager removeItemAtPath:paths[i] error:nil];
}

__attribute__((constructor)) static void SGCrashInstall(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        adoptAbandoned();
        prune();
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.dateFormat = @"yyyy-MM-dd-HH-mm-ss";
        // "pending-" until the launch ends: a clean exit takes the file away, a crash renames it.
        NSString *name = [NSString stringWithFormat:@"pending-%@.txt", [formatter stringFromDate:NSDate.date]];
        NSString *path = [crashDirectory() stringByAppendingPathComponent:name];
        strlcpy(sg_pending, path.fileSystemRepresentation, sizeof(sg_pending));
        // Opened now, so the handler has an fd and nothing to allocate.
        sg_pendingFD = open(sg_pending, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        NSString *header = [NSString stringWithFormat:@"Vitrine %@ on Spotify %@\niOS %@, %@\nstarted %@\n",
                            NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"?",
                            NSBundle.mainBundle.infoDictionary[@"CFBundleVersion"] ?: @"?",
                            NSProcessInfo.processInfo.operatingSystemVersionString, NSProcessInfo.processInfo.hostName, NSDate.date];
        writeAll(sg_pendingFD, header.UTF8String);

        NSSetUncaughtExceptionHandler(&exceptionHandler);
        int signals[] = {SIGABRT, SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP};
        for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); i++) signal(signals[i], crashSignal);
        // A clean exit leaves no report: the file is this launch's, and this launch did not crash.
        [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationWillTerminateNotification object:nil queue:nil
                                                    usingBlock:^(NSNotification *note) {
            [NSFileManager.defaultManager removeItemAtPath:[NSString stringWithUTF8String:sg_pending] error:nil];
        }];
        SGLog(@"crash report: %s, taken away when this launch ends cleanly", sg_pending);
    });
}
