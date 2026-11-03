#import "AlbumShowcase.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"

@implementation SGRAlbumShowcase {
    UIView *_facts, *_shelf;
    UILabel *_factsLine, *_shelfTitle;
    UIView *_cover;
    UIImageView *_coverImage;
    NSArray<UIView *> *_tiles;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.backgroundColor = SGCardBackground();
    self.layer.cornerRadius = 22;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = YES;

    // The album's facts: the release line over its name, as an album's header has them.
    _facts = [UIView new];
    [_facts.layer addSublayer:[self wash]];
    _facts.layer.cornerRadius = 18;
    _facts.layer.cornerCurve = kCACornerCurveContinuous;
    _facts.clipsToBounds = YES;
    [self addSubview:_facts];

    _cover = [UIView new];
    _cover.backgroundColor = [UIColor colorWithWhite:0.35 alpha:1];
    _cover.layer.cornerRadius = 6;
    _cover.layer.cornerCurve = kCACornerCurveContinuous;
    _cover.clipsToBounds = YES;
    [_facts addSubview:_cover];
    _coverImage = [UIImageView new];
    _coverImage.contentMode = UIViewContentModeScaleAspectFill;
    _coverImage.clipsToBounds = YES;
    [_cover addSubview:_coverImage];

    _factsLine = [UILabel new];
    _factsLine.text = @"June 28, 2024\n9 songs · 32 min";
    _factsLine.numberOfLines = 2;
    _factsLine.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
    _factsLine.textColor = [UIColor colorWithWhite:1 alpha:0.55];
    [_facts addSubview:_factsLine];

    // The shelf under the album: further albums by the same artist, three of them, cut at the right edge.
    _shelf = [UIView new];
    [self addSubview:_shelf];
    _shelfTitle = [UILabel new];
    _shelfTitle.text = @"More by the artist";
    _shelfTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    _shelfTitle.textColor = UIColor.whiteColor;
    [_shelf addSubview:_shelfTitle];
    NSMutableArray<UIView *> *tiles = [NSMutableArray array];
    UIColor *colors[] = {SGColorRGB(0x8A8A90), SGColorRGB(0x2F6FA8), SGColorRGB(0xD08B3E)};
    for (NSUInteger i = 0; i < 3; i++) {
        UIView *tile = [UIView new];
        tile.backgroundColor = colors[i];
        tile.layer.cornerRadius = 8;
        tile.layer.cornerCurve = kCACornerCurveContinuous;
        [_shelf addSubview:tile];
        [tiles addObject:tile];
    }
    _tiles = tiles;
    return self;
}

// The card's wash: the slate a page takes before its cover has come, so the card reads as an album in progress.
- (CAGradientLayer *)wash {
    CAGradientLayer *wash = [CAGradientLayer layer];
    wash.colors = @[(id)SGColorRGB(0x274A78).CGColor, (id)SGColorRGB(0x1A2233).CGColor];
    wash.startPoint = CGPointMake(0, 0);
    wash.endPoint = CGPointMake(1, 1);
    return wash;
}

- (void)setArtwork:(UIImage *)artwork {
    _artwork = artwork;
    _coverImage.image = artwork;
    _cover.backgroundColor = artwork ? UIColor.clearColor : [UIColor colorWithWhite:0.35 alpha:1];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), inset = 10;
    CGFloat cardWidth = width - 2 * inset;
    CGFloat top = inset;

    // The page's header: as tall as its cover and the lines beside it.
    CGFloat coverSide = MIN(cardWidth * 0.42, 110);
    _facts.frame = CGRectMake(inset, top, cardWidth, coverSide + 24);
    for (CALayer *layer in _facts.layer.sublayers) if ([layer isKindOfClass:CAGradientLayer.class]) layer.frame = _facts.bounds;
    _cover.frame = CGRectMake(12, 12, coverSide, coverSide);
    _coverImage.frame = _cover.bounds;
    _factsLine.frame = CGRectMake(CGRectGetMaxX(_cover.frame) + 12, 16, CGRectGetWidth(_facts.bounds) - coverSide - 36, 36);
    top = CGRectGetMaxY(_facts.frame) + 10;

    // The shelf, cut by the card's edge the way the real one runs off the screen.
    _shelf.frame = CGRectMake(inset, top, cardWidth, CGRectGetHeight(self.bounds) - top - inset);
    _shelfTitle.frame = CGRectMake(12, 0, CGRectGetWidth(_shelf.bounds) - 24, 24);
    CGFloat tileWidth = (_facts.bounds.size.width - 24 - 2 * 12) / 2.6;
    CGFloat tileTop = CGRectGetMaxY(_shelfTitle.frame) + 8;
    CGFloat tileSide = MAX(20, CGRectGetHeight(_shelf.bounds) - tileTop - 8);
    for (NSUInteger i = 0; i < _tiles.count; i++) _tiles[i].frame = CGRectMake(12 + i * (tileWidth + 12), tileTop, tileWidth, tileSide);
}

@end
