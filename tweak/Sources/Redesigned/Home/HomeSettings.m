// The redesign's Home page of Mod Settings: Top picks and where its cards come from, what stays on Home, and
// one switch per shelf Home has shown lately (HomeShelves.m). Every switch is read as Home lays out, so a
// change needs a restart (SGRestartNote).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Home.h"

static NSString *const kFirstShelf = @"First shelf";

UIViewController *SGRHomeSettingsPage(void) {
    NSArray<NSString *> *shelves = SGRHomeShelvesSeen();
    NSArray<NSString *> *sources = [@[kFirstShelf] arrayByAddingObjectsFromArray:shelves];
    SGModRow *from = SGMenuRow(@"Cards from", sources, ^NSString *{ return SGRHomeTopPicksFrom() ?: kFirstShelf; }, ^(NSInteger index) {
        if (index == 0) [NSUserDefaults.standardUserDefaults removeObjectForKey:SGRKeyHomeTopPicksFrom];
        else [NSUserDefaults.standardUserDefaults setObject:sources[(NSUInteger)index] forKey:SGRKeyHomeTopPicksFrom];
    });
    SGModRow *look = SGSwitchRow(@"Home look", @"Top picks, the tinted shortcut pills and the title's glass pill; off, Home as the redesign had it", SGRKeyHomeLook);
    // The Home look is a launch-time look: the running app keeps the design's layout while its cache holds,
    // so turning it off mid-session leaves Spotify half in the design. Store the switch and offer the restart,
    // the way the Redesigned UI switch does, rather than leaving the page half redesigned.
    look.changed = ^(BOOL on) {
        SGSetEnabled(SGRKeyHomeLook, on);
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Restart Spotify"
            message:on ? @"The Home look comes back when Spotify starts again. Spotify closes now; open it again to see it."
                      : @"Spotify's own Home comes back when Spotify starts again. Spotify closes now; open it again to see it."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Later" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Restart now" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { SGRestartSpotify(); }]];
        [SGTopController() presentViewController:alert animated:YES completion:nil];
    };
    SGModRow *topPicks = SGRHomeTopPicksRow();
    topPicks.waitsOn = SGRKeyHomeLook;
    from.waitsOn = SGRKeyHomeTopPicks;
    SGModRow *colour = SGSwitchRow(@"Color behind Top picks", nil, SGRKeyHomeTopPicksColour);
    colour.waitsOn = SGRKeyHomeTopPicks;

    NSMutableArray<SGModRow *> *rows = [NSMutableArray array];
    for (NSString *identity in shelves) [rows addObject:SGShownRow(identity, nil, SGRHomeShelfHideKey(identity))];
    if (!rows.count) [rows addObject:SGStatRow(@"None seen yet", ^NSString *{ return @""; })];

    return [[SGModPage alloc] initWithTitle:@"Home" intro:SGRestartNote sections:@[
        SGNotedSection(nil, @[look, topPicks, from, colour],
                       @"A shelf Home does not show today leaves Top picks off until it is back."),
        SGSection(@"On Home", @[
            SGShownRow(@"Shortcuts", nil, SGRKeyHomeHideShortcuts),
            SGShownRow(@"DJ", nil, SGRKeyHomeHideDJ),
            SGOptionRow(@"Song suggestions", @"Spotify's carousel of songs to try, when Home offers one", SGRKeyHomeSongSuggestions),
            SGOptionRow(@"Video and playlist previews", @"The cards that play as Home scrolls", SGRKeyHomePreviews),
        ]),
        SGNotedSection(@"Shelves", rows, @"The shelves Home has shown in the last 30 days. A shelf is known by its heading, so one "
                                         @"Spotify names differently in another language is listed again."),
    ] footer:nil];
}
