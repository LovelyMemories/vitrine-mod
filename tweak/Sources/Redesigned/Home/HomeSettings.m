// The redesign's Home page of Mod Settings: Top picks and where its cards come from, what stays on Home, and
// one switch per shelf Home has shown lately (HomeShelves.m). Every switch is read as Home lays out, so a
// change needs a restart (SGRestartNote).
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Redesigned/Kit/SGShader.h"
#import "Home.h"
#import "HomePreviewFeed.h"

static NSString *const kFirstShelf = @"First shelf";

// The card at the top of the page: Home's own header drawn the way the page shows it, a large title in the
// cover's colour with the filter pill and the avatar, and the first shelf's cards running under it, so the
// switches below are read against the Home they make. It is a picture, not the feed: no touches, no live data.
@interface SGRHomeShowcase : UIView
@end

@implementation SGRHomeShowcase {
    UIView *_card, *_ambient, *_play;
    SGAmbientView *_ambientShader;
    UILabel *_title, *_ambientTitle;
    UIView *_pill, *_avatar;
    UIView *_row;
    NSArray<UIView *> *_tiles;
    NSArray<UILabel *> *_names, *_lines;
    CFTimeInterval _pulled;   // when the card last asked Home what it is showing
}

// The card is Home itself: the pictures and the words it shows now, in its own order (HomePreviewFeed.h). Read
// again as the page lays out, no more than twice a second; where Home is not on screen the drawn stand-ins stay.
- (void)refreshFeed {
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _pulled < 0.5) return;
    _pulled = now;
    NSArray<SGRHomeFeedItem *> *items = SGRHomeFeedItems((NSInteger)_tiles.count);
    for (NSUInteger i = 0; i < items.count && i < _tiles.count; i++) {
        SGRHomeFeedItem *item = items[i];
        ((UIImageView *)[_tiles[i] viewWithTag:1]).image = item.image;
        if (item.title.length) _names[i].text = item.title;
        _lines[i].text = item.subtitle ?: @"";
    }
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = SGCardBackground();
    self.clipsToBounds = YES;
    self.layer.cornerRadius = 22;
    self.layer.cornerCurve = kCACornerCurveContinuous;

    _card = [UIView new];
    _card.backgroundColor = SGColorRGB(0x1E3AA8);
    // A cover behind the title, the way Home paints its top in the week's artwork.
    CAGradientLayer *wash = [CAGradientLayer layer];
    wash.colors = @[(id)SGColorRGB(0x2547C8).CGColor, (id)SGColorRGB(0x12246B).CGColor];
    wash.startPoint = CGPointMake(0, 0);
    wash.endPoint = CGPointMake(0.6, 1);
    [_card.layer addSublayer:wash];
    _card.layer.cornerRadius = 18;
    _card.layer.cornerCurve = kCACornerCurveContinuous;
    _card.clipsToBounds = YES;
    [self addSubview:_card];

    _title = [UILabel new];
    _title.text = @"Home";
    _title.textColor = UIColor.whiteColor;
    _title.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    [_card addSubview:_title];

    _pill = [UIView new];
    _pill.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22];
    _pill.layer.cornerRadius = 17;
    [_card addSubview:_pill];
    UIImageView *lines = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal.decrease"]];
    lines.tintColor = UIColor.whiteColor;
    [_pill addSubview:lines];
    _avatar = [UIView new];
    _avatar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.55];
    _avatar.layer.cornerRadius = 15;
    [_pill addSubview:_avatar];

    // The first shelf: four cards of Home's own, a cover each and the two lines under it, running off the edge.
    _row = [UIView new];
    [_card addSubview:_row];
    NSMutableArray<UIView *> *tiles = [NSMutableArray array];
    NSMutableArray<UILabel *> *names = [NSMutableArray array], *lines2 = [NSMutableArray array];
    NSArray<NSString *> *titles = @[@"Two picks", @"For you", @"Lately", @"Bright"];
    NSArray<NSString *> *subtitles = @[@"Made for you", @"Your mix", @"Played a lot", @"New"];
    for (NSInteger i = 0; i < 4; i++) {
        UIView *cell = [UIView new];
        UIImageView *cover = [UIImageView new];
        cover.backgroundColor = i == 0 ? SGColorRGB(0x3B5BD8) : [UIColor colorWithWhite:1 alpha:0.55];
        cover.contentMode = UIViewContentModeScaleAspectFill;
        cover.clipsToBounds = YES;
        cover.layer.cornerRadius = 8;
        cover.layer.cornerCurve = kCACornerCurveContinuous;
        cover.tag = 1;
        [cell addSubview:cover];
        UILabel *name = [UILabel new];
        name.text = titles[i];
        name.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
        name.textColor = UIColor.whiteColor;
        name.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:name];
        UILabel *line = [UILabel new];
        line.text = subtitles[i];
        line.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
        line.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        line.lineBreakMode = NSLineBreakByTruncatingTail;
        [cell addSubview:line];
        [_row addSubview:cell];
        [tiles addObject:cell];
        [names addObject:name];
        [lines2 addObject:line];
    }
    _tiles = tiles;
    _names = names;
    _lines = lines2;

    // Under the shelf, one of Home's wide cards: a scene, its name over it and a play glyph in a glass circle.
    _ambient = [UIView new];
    _ambient.backgroundColor = SGColorRGB(0x2A1B5E);
    _ambient.layer.cornerRadius = 12;
    _ambient.layer.cornerCurve = kCACornerCurveContinuous;
    _ambient.clipsToBounds = YES;
    CAGradientLayer *scene = [CAGradientLayer layer];
    scene.colors = @[(id)SGColorRGB(0x6B2FA8).CGColor, (id)SGColorRGB(0x1B1440).CGColor];
    scene.startPoint = CGPointMake(0, 0);
    scene.endPoint = CGPointMake(1, 1);
    [_ambient.layer addSublayer:scene];
    // Where the device can, the scene is drawn rather than mixed: the newer build's ambient field, in this card's
    // own two colours. The gradient stays under it, and is all that shows where Metal cannot.
    // No Metal in a settings card: see PlayerSettings.m -- a Metal view inside a card the page animates crashed
    // the app in UIKit's animation machinery. The gradient under it is what shows.
    if (NO && [SGAmbientView metalAmbientAvailable]) {
        _ambientShader = [[SGAmbientView alloc] initWithFrame:CGRectZero];
        if (_ambientShader) {
            _ambientShader.topColor = SGColorRGB(0x8E4BE0);
            _ambientShader.bottomColor = SGColorRGB(0x1B1440);
            _ambientShader.amount = 0.3;
            _ambientShader.moving = YES;
            [_ambient addSubview:_ambientShader];
        }
    }
    [_card addSubview:_ambient];
    _ambientTitle = [UILabel new];
    _ambientTitle.text = @"Your week";
    _ambientTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    _ambientTitle.textColor = UIColor.whiteColor;
    [_ambient addSubview:_ambientTitle];
    _play = [UIView new];
    _play.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
    _play.layer.cornerRadius = 15;
    UILabel *glyph = [UILabel new];
    glyph.text = @"▶";
    glyph.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    glyph.textColor = UIColor.whiteColor;
    glyph.textAlignment = NSTextAlignmentCenter;
    glyph.tag = 9;
    [_play addSubview:glyph];
    [_ambient addSubview:_play];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    CGFloat inset = 8;
    _card.frame = CGRectMake(inset, inset, width - 2 * inset, height - inset);
    _card.layer.sublayers.firstObject.frame = _card.bounds;
    CGFloat cardWidth = CGRectGetWidth(_card.bounds), cardHeight = CGRectGetHeight(_card.bounds);
    _title.frame = CGRectMake(16, 10, 200, 42);
    _pill.frame = CGRectMake(cardWidth - 108, 14, 96, 34);
    ((UIView *)_pill.subviews.firstObject).frame = CGRectMake(12, 10, 22, 14);
    _avatar.frame = CGRectMake(64, 2, 30, 30);

    // The shelf: four covers across, the fourth cut by the card's edge.
    CGFloat rowTop = CGRectGetMaxY(_title.frame) + 4, side = 16;
    CGFloat inner = cardWidth - 2 * side;
    CGFloat tileWidth = (inner - 3 * 10) / 3.6;
    CGFloat coverSide = MIN(tileWidth, cardHeight * 0.24);
    CGFloat rowHeight = coverSide + 30;
    _row.frame = CGRectMake(side, rowTop, inner, rowHeight);
    for (NSUInteger i = 0; i < _tiles.count; i++) {
        UIView *cell = _tiles[i];
        cell.frame = CGRectMake(i * (tileWidth + 10), 0, tileWidth, rowHeight);
        UIView *cover = [cell viewWithTag:1];
        cover.frame = CGRectMake(0, 0, coverSide, coverSide);
        _names[i].frame = CGRectMake(0, coverSide + 5, tileWidth, 13);
        _lines[i].frame = CGRectMake(0, coverSide + 18, tileWidth, 12);
    }

    // The wide card takes what is left under the shelf.
    CGFloat ambientTop = CGRectGetMaxY(_row.frame) + 10;
    _ambient.frame = CGRectMake(side, ambientTop, inner, MAX(48, cardHeight - ambientTop - 12));
    _ambientShader.frame = _ambient.bounds;
    _ambient.layer.sublayers.firstObject.frame = _ambient.bounds;
    _ambientTitle.frame = CGRectMake(12, CGRectGetHeight(_ambient.bounds) - 26, CGRectGetWidth(_ambient.bounds) - 60, 18);
    _play.frame = CGRectMake(CGRectGetWidth(_ambient.bounds) - 42, CGRectGetHeight(_ambient.bounds) - 38, 30, 30);
    [_play viewWithTag:9].frame = _play.bounds;
    [self refreshFeed];
}

@end

// The card keeps the height it is given, so it is sized here and handed to the table only when that changes.
@interface SGRHomePage : SGModPage
@property (nonatomic, strong) SGRHomeShowcase *showcase;
@end

@implementation SGRHomePage {
    UIView *_header;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _header = [UIView new];
    [_header addSubview:self.showcase];
    self.tableView.tableHeaderView = _header;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width, inset = table.layoutMargins.left;
    CGFloat cardWidth = width - 2 * inset;
    self.showcase.frame = CGRectMake(inset, 16, cardWidth, round(cardWidth * 0.95));
    CGSize size = CGSizeMake(width, CGRectGetMaxY(self.showcase.frame) + 8);
    if (CGSizeEqualToSize(_header.bounds.size, size)) return;
    _header.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = _header;
}

@end

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
    // The switch stores, and the page's own restart pill offers the restart: no alert of its own, which came up over
    // the rows every time the switch moved.
    look.changed = ^(BOOL on) { SGSetEnabled(SGRKeyHomeLook, on); };
    SGModRow *topPicks = SGRHomeTopPicksRow();
    topPicks.waitsOn = SGRKeyHomeLook;
    from.waitsOn = SGRKeyHomeTopPicks;
    SGModRow *colour = SGSwitchRow(@"Color behind Top picks", nil, SGRKeyHomeTopPicksColour);
    colour.waitsOn = SGRKeyHomeTopPicks;
    // Off Home by default, as the 1.0.1 build has them: the page is shelves and Top picks. These three rows show
    // the state itself, so their switch is on when the part is on.
    SGModRow *shortcuts = SGShownRow(@"Shortcuts", nil, SGRKeyHomeHideShortcuts);
    shortcuts.inverted = NO;
    shortcuts.defaultOn = NO;
    SGModRow *dj = SGShownRow(@"DJ", nil, SGRKeyHomeHideDJ);
    dj.inverted = NO;
    dj.defaultOn = NO;
    SGModRow *podcasts = SGShownRow(@"Podcasts and audiobooks", nil, SGRKeyHomeHidePodcasts);
    podcasts.inverted = NO;
    podcasts.defaultOn = NO;

    NSMutableArray<SGModRow *> *rows = [NSMutableArray array];
    for (NSString *identity in shelves) [rows addObject:SGShownRow(identity, nil, SGRHomeShelfHideKey(identity))];
    if (!rows.count) [rows addObject:SGStatRow(@"None seen yet", ^NSString *{ return @""; })];

    SGRHomePage *page = [[SGRHomePage alloc] initWithTitle:@"Home" intro:SGRestartNote sections:@[
        SGNotedSection(nil, @[look, topPicks, from, colour],
                       @"A shelf Home does not show today leaves Top picks off until it is back."),
        SGSection(@"On Home", @[
            shortcuts,
            dj,
            SGOptionRow(@"Song suggestions", @"Spotify's carousel of songs to try, when Home offers one", SGRKeyHomeSongSuggestions),
            SGOptionRow(@"Video and playlist previews", @"The cards that play as Home scrolls", SGRKeyHomePreviews),
            podcasts,
        ]),
        SGNotedSection(@"Shelves", rows, @"The shelves Home has shown in the last 30 days. A shelf is known by its heading, so one "
                                         @"Spotify names differently in another language is listed again."),
    ] footer:nil];
    page.showcase = [SGRHomeShowcase new];
    return page;
}
