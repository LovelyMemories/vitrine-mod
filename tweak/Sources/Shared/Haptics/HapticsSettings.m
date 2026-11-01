// The Vibrations page, under either look (App/ModSettings.x links it from the main page): the preview at the
// top (SGVibrationsPreview.m), then a card per kind, the way the Audio effects page has one per effect.
// Controls is a switch with its strength under it. Music Haptics is the mod's own from the sound while Spotify
// is in front, with its strength and what it follows (a choice that also says whether the rumble plays, rather
// than a switch of its own that one choice would leave with nothing to do) under it. The rows under a switch
// stay where they are, grayed, while it is off. Each strength's slider plays a tap at the new strength with
// each step, and the preview ripples with it.
//
// In the Background, the song handed to iOS's own Music Haptics on the lock screen, is gone from the page:
// SGMusicHapticsInBackground answers NO, so nothing is named to iOS and the mod's own never stands down.
// Shared/Haptics/SystemMusicHaptics.x stays for SGSpotifyISRC, which a lyrics source asks (BiniLyrics.m).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Haptics.h"
#import "SGVibrationsPreview.h"

static NSString *const kMusicInfo = @"The iPhone taps along with the drums and rumbles under the bass, worked out from the sound as Spotify plays it. Only while Spotify is open: iOS stops an app's own haptics in the background, and a song playing on another device through Connect has no sound here to follow.";

NSNotificationName const SGMusicHapticsSwitchesChangedNotification = @"SGMusicHapticsSwitchesChangedNotification";
NSNotificationName const SGSystemMusicHapticsChangedNotification = @"SGSystemMusicHapticsChangedNotification";

static NSString *sg_status;
static BOOL sg_systemOff;

NSString *SGMusicHapticsStatus(void) {
    return sg_status ?: @"Waiting";
}

void SGSetMusicHapticsStatus(NSString *status) {
    sg_status = [status copy];
}

BOOL SGSystemMusicHapticsOn(void) {
    return !sg_systemOff;
}

void SGSetSystemMusicHapticsOn(BOOL on) {
    if (sg_systemOff == !on) return;
    sg_systemOff = !on;
    [NSNotificationCenter.defaultCenter postNotificationName:SGSystemMusicHapticsChangedNotification object:nil];
}

BOOL SGMusicHapticsOn(void) {
    return SGFlag(SGKeyMusicHaptics, NO);
}

BOOL SGMusicHapticsListedByInstall(void) {
    return [[NSBundle.mainBundle objectForInfoDictionaryKey:@"MusicHapticsSupported"] boolValue];
}

// Gone from the page: the song is never handed to iOS's Music Haptics, and the mod's own haptics never stand
// down for it. The iOS bridge reads this, so it does nothing.
BOOL SGMusicHapticsInBackground(void) {
    return NO;
}

void SGMigrateMusicHaptics(void) {
    // The redesign's old key first: SGMigrateKey leaves it where it is once the new one exists.
    SGMigrateKey(SGKeyMusicHapticsWas, SGKeyMusicHaptics);
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    if (![store objectForKey:SGKeyMusicHapticsMode]) return;
    NSInteger mode = SGInt(SGKeyMusicHapticsMode, 0);
    SGSetEnabled(SGKeyMusicHaptics, mode == 1);
    [store removeObjectForKey:SGKeyMusicHapticsMode];
    SGLog(@"music haptics: the old choice %ld is now Music Haptics %@", (long)mode, mode == 1 ? @"on" : @"off");
}

static NSArray<NSString *> *followsNames(void) {
    return @[@"Everything", @"Beat", @"Bass"];
}

static NSArray<NSString *> *followsNotes(void) {
    return @[@"A tap on each kick and snare, and a rumble under the bass",
             @"A tap on each kick and snare, no rumble",
             @"A tap on each kick, and a rumble under the bass"];
}

static void strengthRange(NSString *key, NSInteger *minimum, NSInteger *maximum) {
    BOOL music = [key isEqualToString:SGKeyMusicStrength];
    *minimum = music ? SGMusicStrengthMin : SGControlStrengthMin;
    *maximum = music ? SGMusicStrengthMax : SGControlStrengthMax;
}

double SGHapticsStrength(NSString *key) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return MAX(minimum, MIN(maximum, SGInt(key, 100))) / 100.0;
}

SGMusicFollows SGMusicHapticsFollows(void) {
    NSInteger follows = SGInt(SGKeyMusicFollows, SGMusicFollowsEverything);
    return follows >= SGMusicFollowsEverything && follows <= SGMusicFollowsBass ? (SGMusicFollows)follows : SGMusicFollowsEverything;
}

// A percentage slider over a strength key, telling `changed` each step it stores.
static SGModRow *strengthRow(NSString *key, void (^changed)(void)) {
    NSInteger minimum, maximum;
    strengthRange(key, &minimum, &maximum);
    return SGSliderRow(@"Strength", nil, minimum, maximum, SGStrengthStep,
        ^double { return SGHapticsStrength(key) * 100; },
        ^(double value) {
            SGSetInt(key, lround(value));
            if (changed) changed();
        },
        ^NSString *(double value) { return [NSString stringWithFormat:@"%ld%%", lround(value)]; });
}

// The cards, `preview` told when something it reads out changes and shown the slider's taps.
static NSArray<SGModSection *> *sections(SGVibrationsPreview *preview) {
    SGMigrateMusicHaptics();
    __weak SGVibrationsPreview *weakPreview = preview;
    SGModRow *controls = SGSwitchRow(@"Controls", nil, SGKeyControlHaptics);
    controls.changed = ^(BOOL on) { [weakPreview reload]; };
    SGModRow *controlStrength = strengthRow(SGKeyControlStrength, ^{
        // Felt as it is set, and seen: a tap at the new strength with each step, and its ripple.
        SGPlayFeedback(SGFeedbackAdd);
        [weakPreview rippleAt:SGHapticsStrength(SGKeyControlStrength)];
    });
    controlStrength.waitsOn = SGKeyControlHaptics;

    void (^switched)(BOOL) = ^(BOOL on) {
        [NSNotificationCenter.defaultCenter postNotificationName:SGMusicHapticsSwitchesChangedNotification object:nil];
        [weakPreview reload];
    };
    SGModRow *music = SGOptionRow(@"Music Haptics", nil, SGKeyMusicHaptics);
    music.info = kMusicInfo;
    music.changed = switched;
    SGModRow *musicStrength = strengthRow(SGKeyMusicStrength, ^{
        // As Controls' Strength: a kick at the new strength with each step, and its ripple.
        SGMusicHapticsSettingsChanged();
        SGMusicHapticsPreview();
        [weakPreview rippleAt:SGHapticsStrength(SGKeyMusicStrength) / 2];
    });
    musicStrength.waitsOn = SGKeyMusicHaptics;
    SGModRow *follows = SGChoiceRow(@"Follows", nil, SGKeyMusicFollows, followsNames(), SGMusicFollowsEverything);
    follows.choiceNotes = followsNotes();
    follows.chosen = ^(NSInteger index) { SGMusicHapticsSettingsChanged(); };
    follows.waitsOn = SGKeyMusicHaptics;

    return @[
        SGSection(nil, @[SGWithSymbol(controls, @"hand.tap"), controlStrength]),
        SGSection(nil, @[SGWithSymbol(music, @"waveform"), musicStrength, follows]),
    ];
}

#pragma mark - the page

@interface SGVibrationsPage : SGModPage
@property (nonatomic, strong) SGVibrationsPreview *preview;
@end

@implementation SGVibrationsPage

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView = self.preview;
}

// The header keeps the height it is given, so it is sized here and handed back to the table only when that
// changes (a table header set on every pass lays the table out again forever).
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width;
    self.preview.layoutMargins = UIEdgeInsetsMake(0, table.layoutMargins.left, 0, table.layoutMargins.right);
    CGSize size = CGSizeMake(width, [self.preview heightForWidth:width]);
    if (CGSizeEqualToSize(self.preview.bounds.size, size)) return;
    self.preview.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = self.preview;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.preview reload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.preview.listening = YES;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.preview.listening = NO;
}

@end

UIViewController *SGVibrationsSettingsPage(void) {
    SGVibrationsPreview *preview = [SGVibrationsPreview new];
    SGVibrationsPage *page = [[SGVibrationsPage alloc] initWithTitle:@"Vibrations" intro:nil sections:sections(preview) footer:nil];
    page.preview = preview;
    return page;
}

