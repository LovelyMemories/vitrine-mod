// SGLogFile.h says what this keeps and why the write is queued.
#import "SGLogFile.h"
#import <os/lock.h>

// A few megabytes each, so a long session still fits and the folder stays small.
static const unsigned long long kLogLimit = 3 * 1024 * 1024;
// A feature that logs per event, per packet or per frame must not fill the disk with it: the lines kept are capped
// here rather than at the source, so a flood costs a counter and nothing else.
static const unsigned kLinesPerSecond = 40;
static os_unfair_lock throttleLock = OS_UNFAIR_LOCK_INIT;
static CFAbsoluteTime windowStart;
static unsigned windowLines;

static dispatch_queue_t logQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("spotifyglass.logfile", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0));
    });
    return queue;
}

static NSURL *logFolder(void) {
    static NSURL *folder;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        folder = [support URLByAppendingPathComponent:@"Vitrine/Logs" isDirectory:YES];
    });
    return folder;
}

static NSString *livePath(void) {
    return [logFolder() URLByAppendingPathComponent:@"log.txt"].path;
}

static NSString *rolledPath(void) {
    return [logFolder() URLByAppendingPathComponent:@"log.1.txt"].path;
}

// The time first, so a file with two runs in it still reads in order.
static NSData *lineData(NSString *line) {
    NSDateFormatter *stamp = [[NSDateFormatter alloc] init];
    stamp.dateFormat = @"MM-dd HH:mm:ss.SSS";
    return [[NSString stringWithFormat:@"%@ %@\n", [stamp stringFromDate:NSDate.date], line] dataUsingEncoding:NSUTF8StringEncoding];
}

static void rollOverIfNeeded(void) {
    NSFileManager *files = NSFileManager.defaultManager;
    NSDictionary *attributes = [files attributesOfItemAtPath:livePath() error:nil];
    if ([attributes[NSFileSize] unsignedLongLongValue] < kLogLimit) return;
    [files removeItemAtPath:rolledPath() error:nil];
    [files moveItemAtPath:livePath() toPath:rolledPath() error:nil];
}

void SGLogFileWrite(NSString *line) {
    if (!line.length) return;
    os_unfair_lock_lock(&throttleLock);
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (now - windowStart >= 1) {
        windowStart = now;
        windowLines = 0;
    }
    BOOL allow = windowLines++ < kLinesPerSecond;
    os_unfair_lock_unlock(&throttleLock);
    if (!allow) return;
    // The stamp is put on the queue too: a formatter is not something the render thread should make.
    dispatch_async(logQueue(), ^{
        NSData *data = lineData(line);
        NSFileManager *files = NSFileManager.defaultManager;
        [files createDirectoryAtURL:logFolder() withIntermediateDirectories:YES attributes:nil error:nil];
        rollOverIfNeeded();
        NSString *path = livePath();
        if (![files fileExistsAtPath:path]) {
            [data writeToFile:path atomically:NO];
            return;
        }
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!handle) return;
        @try {
            [handle seekToEndOfFile];
            [handle writeData:data];
        } @catch (NSException *exception) {
        } @finally {
            [handle closeFile];
        }
    });
}

NSArray<NSString *> *SGLogFilePaths(void) {
    NSMutableArray<NSString *> *paths = [NSMutableArray array];
    for (NSString *path in @[livePath(), rolledPath()]) {
        NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
        if (attributes) [paths addObject:path];
    }
    return paths;
}

void SGLogFileDeleteAll(void) {
    for (NSString *path in @[livePath(), rolledPath()]) [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}
