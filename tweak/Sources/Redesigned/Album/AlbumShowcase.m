// The albums page's card: an album's page drawn small, the way the redesign lays one out -- the cover under the
// title, a row of its own buttons, the tracks with their lengths, and what sits under them. It is a picture of the
// page, not the page: no live data, no touches, and one album's worth of it (Evolve, whose shape everyone knows),
// so the switches below are read against something rather than against nothing.
#import "AlbumShowcase.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"

// The tracks the card has room for, and what each one shows: a number, a name, a length. The example is an album
// whose shape everyone knows, so a switch that takes a section off reads against something real.
static NSString *const kTitles[] = {@"I Don't Know Why", @"Whatever It Takes", @"Believer", @"Thunder"};
static NSString *const kLengths[] = {@"3:10", @"3:21", @"3:24", @"3:07"};

@implementation SGRAlbumShowcase {
    UIView *_hero, *_cover, *_controls, *_tracks, *_shelf;
    CAGradientLayer *_wash;
    UIImageView *_coverImage;
    UILabel *_title, *_creator, *_kind, *_foot, *_shelfTitle, *_notes;
    NSMutableArray<UIView *> *_buttons, *_rows, *_tiles;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = SGCardBackground();
    self.layer.cornerRadius = 22;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = YES;

    // The page's head: the cover's color runs under it and fades into the card, the cover sits on the left with
    // the album's name, its artist and what kind of record it is beside it.
    _hero = [UIView new];
    _hero.clipsToBounds = YES;
    _wash = [CAGradientLayer layer];
    _wash.colors = @[(id)SGColorRGB(0x274A78).CGColor, (id)SGCardBackground().CGColor];
    _wash.startPoint = CGPointMake(0, 0);
    _wash.endPoint = CGPointMake(0.2, 1);
    [_hero.layer addSublayer:_wash];
    [self addSubview:_hero];

    _cover = [UIView new];
    _cover.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1];
    _cover.layer.cornerRadius = 6;
    _cover.layer.cornerCurve = kCACornerCurveContinuous;
    _cover.clipsToBounds = YES;
    [_hero addSubview:_cover];
    _coverImage = [UIImageView new];
    _coverImage.contentMode = UIViewContentModeScaleAspectFill;
    _coverImage.clipsToBounds = YES;
    [_cover addSubview:_coverImage];

    _title = [UILabel new];
    _title.text = @"Evolve";
    _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _title.textColor = UIColor.whiteColor;
    _title.numberOfLines = 2;
    [_hero addSubview:_title];

    _creator = [UILabel new];
    _creator.text = @"Imagine Dragons";
    _creator.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    _creator.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    [_hero addSubview:_creator];

    _kind = [UILabel new];
    _kind.text = @"Album · 2017";
    _kind.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _kind.textColor = [UIColor colorWithWhite:1 alpha:0.45];
    [_hero addSubview:_kind];

    // The album's own three: shuffle, add and play, as its page has them, drawn and not touched.
    _controls = [UIView new];
    [self addSubview:_controls];
    NSArray<NSString *> *glyphs = @[@"⇄", @"+", @"▶"];
    _buttons = [NSMutableArray array];
    for (NSUInteger i = 0; i < glyphs.count; i++) {
        UIView *button = [UIView new];
        BOOL play = i == 2;
        button.backgroundColor = play ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.12];
        button.layer.cornerRadius = 16;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        UILabel *glyph = [UILabel new];
        glyph.text = glyphs[i];
        glyph.font = [UIFont systemFontOfSize:play ? 13 : 14 weight:UIFontWeightSemibold];
        glyph.textColor = play ? UIColor.blackColor : [UIColor colorWithWhite:1 alpha:0.85];
        glyph.textAlignment = NSTextAlignmentCenter;
        glyph.tag = 9;
        glyph.frame = CGRectMake(0, 0, 32, 32);
        [button addSubview:glyph];
        [_controls addSubview:button];
        [_buttons addObject:button];
    }

    // The tracks: a number, a name and how long it runs, over hairlines, as the page lists them.
    _tracks = [UIView new];
    [self addSubview:_tracks];
    _rows = [NSMutableArray array];
    for (NSUInteger i = 0; i < 4; i++) {
        UILabel *number = [UILabel new];
        number.text = [NSString stringWithFormat:@"%lu", (unsigned long)i + 1];
        number.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        number.textColor = [UIColor colorWithWhite:1 alpha:0.35];
        UILabel *name = [UILabel new];
        name.text = kTitles[i];
        name.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
        name.textColor = [UIColor colorWithWhite:1 alpha:0.9];
        name.lineBreakMode = NSLineBreakByTruncatingTail;
        UILabel *length = [UILabel new];
        length.text = kLengths[i];
        length.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightRegular];
        length.textColor = [UIColor colorWithWhite:1 alpha:0.35];
        length.textAlignment = NSTextAlignmentRight;
        UIView *row = [UIView new];
        [row addSubview:number];
        [row addSubview:name];
        [row addSubview:length];
        if (i) {
            UIView *hair = [UIView new];
            hair.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
            hair.tag = 8;
            [row addSubview:hair];
        }
        [_tracks addSubview:row];
        [_rows addObject:row];
    }

    // Under the tracks, the album's notes, a line of them, and where it was made.
    _notes = [UILabel new];
    _notes.text = @"Evolve is Imagine Dragons at their most direct: big drums, voices stacked into a chorus, and "
                  @"the three-minute pop song taken as far as it goes.";
    _notes.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _notes.textColor = [UIColor colorWithWhite:1 alpha:0.4];
    _notes.numberOfLines = 2;
    [self addSubview:_notes];

    // The shelf under the album: further albums by the same artist, cut by the card's edge.
    _shelf = [UIView new];
    [self addSubview:_shelf];
    _shelfTitle = [UILabel new];
    _shelfTitle.text = @"More by the artist";
    _shelfTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    _shelfTitle.textColor = UIColor.whiteColor;
    [_shelf addSubview:_shelfTitle];
    _tiles = [NSMutableArray array];
    UIColor *colors[] = {SGColorRGB(0x8A8A90), SGColorRGB(0x2F6FA8), SGColorRGB(0xD08B3E)};
    for (NSUInteger i = 0; i < 3; i++) {
        UIView *tile = [UIView new];
        tile.backgroundColor = colors[i];
        tile.layer.cornerRadius = 8;
        tile.layer.cornerCurve = kCACornerCurveContinuous;
        [_shelf addSubview:tile];
        [_tiles addObject:tile];
    }

    _foot = [UILabel new];
    _foot.text = @"June 23, 2017 · 11 songs · 39 min";
    _foot.font = [UIFont systemFontOfSize:10.5 weight:UIFontWeightRegular];
    _foot.textColor = [UIColor colorWithWhite:1 alpha:0.3];
    [self addSubview:_foot];
    return self;
}

- (void)setArtwork:(UIImage *)artwork {
    _artwork = artwork;
    _coverImage.image = artwork;
    _cover.backgroundColor = artwork ? UIColor.clearColor : [UIColor colorWithWhite:0.35 alpha:1];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), inset = 12;
    CGFloat inner = width - 2 * inset;

    // The head is as tall as its cover and the lines beside it.
    CGFloat coverSide = MIN(inner * 0.34, 92);
    CGFloat heroHeight = coverSide + 28;
    _hero.frame = CGRectMake(0, 0, width, heroHeight);
    _wash.frame = _hero.bounds;
    _cover.frame = CGRectMake(inset, 14, coverSide, coverSide);
    _coverImage.frame = _cover.bounds;
    CGFloat textX = CGRectGetMaxX(_cover.frame) + 12, textWidth = width - textX - inset;
    _title.frame = CGRectMake(textX, 22, textWidth, 38);
    _creator.frame = CGRectMake(textX, CGRectGetMaxY(_title.frame) + 2, textWidth, 16);
    _kind.frame = CGRectMake(textX, CGRectGetMaxY(_creator.frame) + 1, textWidth, 15);

    // The buttons sit under the head, at the right, as the page puts them.
    _controls.frame = CGRectMake(inset, CGRectGetMaxY(_hero.frame) + 2, inner, 32);
    CGFloat buttonX = inner;
    for (UIView *button in _buttons.reverseObjectEnumerator) {
        buttonX -= 32;
        button.frame = CGRectMake(buttonX, 0, 32, 32);
        [button viewWithTag:9].frame = button.bounds;
        buttonX -= 10;
    }

    // Four tracks over hairlines, then the notes.
    CGFloat rowHeight = 30;
    _tracks.frame = CGRectMake(inset, CGRectGetMaxY(_controls.frame) + 8, inner, rowHeight * _rows.count);
    for (NSUInteger i = 0; i < _rows.count; i++) {
        UIView *row = _rows[i];
        row.frame = CGRectMake(0, i * rowHeight, inner, rowHeight);
        [row viewWithTag:8].frame = CGRectMake(0, 0, inner, 1 / UIScreen.mainScreen.scale);
        [row.subviews objectAtIndex:0].frame = CGRectMake(0, 0, 18, rowHeight);
        [row.subviews objectAtIndex:1].frame = CGRectMake(22, 0, inner - 22 - 44, rowHeight);
        [row.subviews objectAtIndex:2].frame = CGRectMake(inner - 44, 0, 44, rowHeight);
    }

    CGFloat notesTop = CGRectGetMaxY(_tracks.frame) + 8;
    _notes.frame = CGRectMake(inset, notesTop, inner, 30);

    // The shelf, cut by the card's edge the way the real one runs off the screen.
    CGFloat shelfTop = CGRectGetMaxY(_notes.frame) + 10;
    _shelf.frame = CGRectMake(inset, shelfTop, inner, CGRectGetHeight(self.bounds) - shelfTop - 26);
    _shelfTitle.frame = CGRectMake(0, 0, CGRectGetWidth(_shelf.bounds), 20);
    CGFloat tileTop = CGRectGetMaxY(_shelfTitle.frame) + 6;
    CGFloat tileWidth = (CGRectGetWidth(_shelf.bounds) - 2 * 10) / 2.4;
    CGFloat tileSide = 64;
    for (NSUInteger i = 0; i < _tiles.count; i++) {
        _tiles[i].frame = CGRectMake(i * (tileWidth + 10), tileTop, tileWidth, tileSide);
    }

    _foot.frame = CGRectMake(inset, CGRectGetHeight(self.bounds) - 20, inner, 14);
}

@end
