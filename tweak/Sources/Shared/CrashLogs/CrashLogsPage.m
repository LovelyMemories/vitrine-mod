// The Crash logs page: what the mod caught when Spotify last died, newest first, each file shared with the
// share sheet so it can be sent off the phone. A launch that ends cleanly takes its own file away (Core/SGCrash.h),
// so a file here is a crash.
#import "Core/SGCore.h"
#import "Core/SGCrash.h"
#import "Core/SGLogFile.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "CrashLogs.h"

static NSString *sizeText(NSString *path) {
    NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    return [NSByteCountFormatter stringFromByteCount:[attributes[NSFileSize] longLongValue] countStyle:NSByteCountFormatterCountStyleFile];
}

static void shareFile(NSString *path) {
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) return;
    UIActivityViewController *sheet = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:path]]
                                                                      applicationActivities:nil];
    [SGTopController() presentViewController:sheet animated:YES completion:nil];
}

UIViewController *SGCrashLogsPage(void) {
    NSDateFormatter *stamp = [NSDateFormatter new];
    stamp.dateFormat = @"yyyy-MM-dd-HH-mm-ss";
    NSDateFormatter *shown = [NSDateFormatter new];
    shown.dateStyle = NSDateFormatterMediumStyle;
    shown.timeStyle = NSDateFormatterShortStyle;

    // The crash reports are kept, and still take their file away on a clean launch (Core/SGCrash.h), but they no
    // longer have a block of their own on this page: one list of files, the log. A crash report is shown under the
    // log files when there is one, with a line saying what it is.
    NSMutableArray<SGModRow *> *rows = [NSMutableArray array];
    for (NSString *path in SGCrashReportPaths()) {
        NSString *name = path.lastPathComponent;
        NSString *datePart = [[name stringByDeletingPathExtension] stringByReplacingOccurrencesOfString:@"crash-" withString:@""];
        NSDate *date = [stamp dateFromString:datePart];
        SGModRow *row = SGActionRow(date ? [shown stringFromDate:date] : name, sizeText(path), ^{ shareFile(path); });
        [rows addObject:row];
    }

    // The mod's own lines, kept on the phone by SGLog (Core/SGLogFile.h): every log line, from this launch and the
    // one before it, whatever FLEX or the system log holds. A tap shares the file.
    NSMutableArray<SGModRow *> *logs = [NSMutableArray array];
    for (NSString *path in SGLogFilePaths()) {
        [logs addObject:SGActionRow(path.lastPathComponent, sizeText(path), ^{ shareFile(path); })];
    }
    // One list on the page: the log files, and under them a crash report when this launch follows one, since a report
    // is worth sharing exactly then. One delete row, at the end, for everything in it: two rows between the files
    // read as two more files.
    NSMutableArray<SGModRow *> *all = [NSMutableArray arrayWithArray:logs];
    [all addObjectsFromArray:rows];
    if (all.count) {
        [all addObject:SGActionRow(@"Delete all files", nil, ^{
            UIAlertController *ask = [UIAlertController alertControllerWithTitle:@"Delete all files?"
                                                                        message:@"The log files and the crash reports are removed from this iPhone; nothing else changes."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            [ask addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [ask addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                SGLogFileDeleteAll();
                SGCrashDeleteAll();
                SGLog(@"crash logs: deleted");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SGTopController().navigationController popViewControllerAnimated:YES];
                });
            }]];
            [SGTopController() presentViewController:ask animated:YES completion:nil];
        })];
    } else {
        [all addObject:SGStatRow(@"Nothing has been written yet", ^NSString *{ return @"—"; })];
    }

    return [[SGModPage alloc] initWithTitle:@"Crash logs" intro:nil
                                   sections:@[SGSection(nil, all)] footer:
            @"A crash report is the reason and the stack of the thread that died, and it is taken away by a launch that "
            @"ends cleanly; one here is a crash, and the newest five are kept. The log file is every line the mod wrote, "
            @"with its times. Tap a file to share it."];
}
