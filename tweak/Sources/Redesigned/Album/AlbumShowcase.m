// The albums page's card: an album's head drawn full bleed, the way the newer build shows it -- the cover across the
// whole card with its name, its artist and what kind of record it is over it, and the album's own three buttons
// under them: shuffle, Play, and add. A picture of the page, not the page: no touches, no live data.
#import "AlbumShowcase.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"

@implementation SGRAlbumShowcase {
    UIImageView *_cover;
    UIView *_shade, *_controls;
    UILabel *_title, *_artist, *_kind;
    NSMutableArray<UIView *> *_buttons;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = SGCardBackground();
    self.layer.cornerRadius = 22;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = YES;

    // The cover fills the card: what an album page opens with.
    _cover = [UIImageView new];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.clipsToBounds = YES;
    _cover.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
    [self addSubview:_cover];

    // A shade under the words, darker at the foot, so white text reads on any cover.
    _shade = [UIView new];
    CAGradientLayer *shade = [CAGradientLayer layer];
    shade.colors = @[(id)[UIColor colorWithWhite:0 alpha:0.05].CGColor,
                     (id)[UIColor colorWithWhite:0 alpha:0.45].CGColor,
                     (id)[UIColor colorWithWhite:0 alpha:0.78].CGColor];
    shade.locations = @[@0, @0.55, @1];
    [_shade.layer addSublayer:shade];
    [self addSubview:_shade];

    _title = [UILabel new];
    _title.text = @"LOOM";
    _title.font = [UIFont systemFontOfSize:26 weight:UIFontWeightBold];
    _title.textColor = UIColor.whiteColor;
    _title.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_title];

    _artist = [UILabel new];
    _artist.text = @"Imagine Dragons";
    _artist.font = [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
    _artist.textColor = [UIColor colorWithWhite:1 alpha:0.85];
    _artist.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_artist];

    _kind = [UILabel new];
    _kind.text = @"Album · 2024";
    _kind.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
    _kind.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    _kind.textAlignment = NSTextAlignmentCenter;
    [self addSubview:_kind];

    // The album's own three, as its page has them: shuffle and add as glass circles, Play as the white pill.
    _controls = [UIView new];
    [self addSubview:_controls];
    _buttons = [NSMutableArray array];
    NSArray<NSString *> *glyphs = @[@"⇄", @"▶  Play", @"+"];
    for (NSUInteger i = 0; i < glyphs.count; i++) {
        BOOL play = i == 1;
        UIView *button = [UIView new];
        button.backgroundColor = play ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.22];
        button.layer.cornerRadius = 24;
        button.layer.cornerCurve = kCACornerCurveContinuous;
        UILabel *glyph = [UILabel new];
        glyph.text = glyphs[i];
        glyph.font = [UIFont systemFontOfSize:play ? 17 : 16 weight:UIFontWeightSemibold];
        glyph.textColor = play ? UIColor.blackColor : UIColor.whiteColor;
        glyph.textAlignment = NSTextAlignmentCenter;
        glyph.tag = 9;
        [button addSubview:glyph];
        [_controls addSubview:button];
        [_buttons addObject:button];
    }
    return self;
}

- (void)setArtwork:(UIImage *)artwork {
    _artwork = artwork;
    _cover.image = artwork;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    _cover.frame = self.bounds;
    _shade.frame = self.bounds;
    _shade.layer.sublayers.firstObject.frame = _shade.bounds;

    // The words sit over the cover's foot, the buttons under them.
    CGFloat controlsHeight = 48, controlsTop = height - 20 - controlsHeight;
    CGFloat gap = 6, inset = 8;
    CGFloat playWidth = MIN(180, width - 2 * (48 + inset) - 2 * 32);
    CGFloat total = 48 + inset + playWidth + inset + 48;
    CGFloat left = round((width - total) / 2);
    CGFloat x = left;
    for (NSUInteger i = 0; i < _buttons.count; i++) {
        UIView *button = _buttons[i];
        CGFloat w = i == 1 ? playWidth : 48;
        button.frame = CGRectMake(x, controlsTop, w, controlsHeight);
        [button viewWithTag:9].frame = button.bounds;
        x += w + inset;
    }
    _controls.frame = CGRectMake(0, controlsTop, width, controlsHeight);

    _kind.frame = CGRectMake(16, controlsTop - 24 - gap, width - 32, 18);
    _artist.frame = CGRectMake(16, CGRectGetMinY(_kind.frame) - 24, width - 32, 22);
    _title.frame = CGRectMake(16, CGRectGetMinY(_artist.frame) - 36, width - 32, 34);
}

@end
