#import "PlayerBackgroundStrip.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"

static const CGFloat kCardWidth = 104, kCardHeight = 132, kGap = 10, kSide = 12;

@implementation SGRPlayerBackgroundStrip {
    NSArray<NSString *> *_names;
    void (^_picked)(NSInteger index);
    NSMutableArray<UIView *> *_cards;
    UIScrollView *_run;
    NSInteger _selected;
}

- (instancetype)initWithFrame:(CGRect)frame names:(NSArray<NSString *> *)names picked:(void (^)(NSInteger))picked {
    if (!(self = [super initWithFrame:frame])) return nil;
    _names = [names copy];
    _picked = [picked copy];
    _cards = [NSMutableArray array];
    _selected = -1;
    self.backgroundColor = UIColor.clearColor;

    _run = [UIScrollView new];
    _run.showsHorizontalScrollIndicator = NO;
    _run.alwaysBounceHorizontal = YES;
    _run.clipsToBounds = NO;
    [self addSubview:_run];

    for (NSUInteger i = 0; i < names.count; i++) {
        UIControl *card = [UIControl new];
        card.tag = (NSInteger)i;
        [card addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        card.accessibilityLabel = SGLocalized(names[i]);
        card.layer.cornerRadius = 16;
        card.layer.cornerCurve = kCACornerCurveContinuous;
        card.backgroundColor = SGCardBackground();

        UIImageView *picture = [UIImageView new];
        picture.tag = 1;
        picture.contentMode = UIViewContentModeScaleAspectFill;
        picture.clipsToBounds = YES;
        picture.layer.cornerRadius = 12;
        picture.layer.cornerCurve = kCACornerCurveContinuous;
        picture.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1];
        picture.userInteractionEnabled = NO;
        [card addSubview:picture];

        UILabel *title = [UILabel new];
        title.tag = 2;
        title.text = SGLocalized(names[i]);
        title.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        title.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        title.textAlignment = NSTextAlignmentCenter;
        title.lineBreakMode = NSLineBreakByTruncatingTail;
        title.userInteractionEnabled = NO;
        [card addSubview:title];

        [_run addSubview:card];
        [_cards addObject:card];
    }
    return self;
}

- (void)setArtwork:(UIImage *)artwork {
    _artwork = artwork;
    for (NSUInteger i = 0; i < _cards.count; i++) [self paint:(NSInteger)i];
}

- (void)setSelected:(NSInteger)selected {
    _selected = selected;
    for (UIView *card in _cards) {
        BOOL on = card.tag == selected;
        card.layer.borderWidth = on ? 2 : 0;
        card.layer.borderColor = SGGreen().CGColor;
    }
}

// Each card is the cover drawn the way its background draws it: held still, blurred, folded, as hills, as curtains
// of light, or not at all. Small on purpose -- it says which look it is, not what it will look like full screen.
- (void)paint:(NSInteger)index {
    UIView *card = _cards[(NSUInteger)index];
    UIImageView *picture = (UIImageView *)[card viewWithTag:1];
    for (CALayer *layer in [picture.layer.sublayers copy]) [layer removeFromSuperlayer];
    picture.image = _artwork;
    picture.alpha = 1;
    picture.layer.filters = nil;

    NSString *name = _names[(NSUInteger)index];
    BOOL still = [name isEqualToString:@"Still"];
    BOOL colours = [name isEqualToString:@"Colors"];
    BOOL fluid = [name isEqualToString:@"Fluid"];
    BOOL animated = [name isEqualToString:@"Animated"];
    BOOL visualiser = [name isEqualToString:@"Visualizer"];
    BOOL aurora = [name isEqualToString:@"Aurora"];
    BOOL black = [name isEqualToString:@"Black"];

    if (still) {
        picture.alpha = 0.9;
    } else if (colours) {
        picture.alpha = 0.75;
    } else if (fluid) {
        picture.alpha = 0.85;
    } else if (animated) {
        picture.alpha = 0.9;
    } else if (visualiser) {
        picture.alpha = 0.55;   // the hills stand over it
    } else if (aurora) {
        picture.alpha = 0;      // curtains of light on black instead
    } else if (black) {
        picture.alpha = 0;
    }
    if (fluid || animated || visualiser || colours) {
        // A soft wash over the cover, in its own colours, as the moving field reads.
        CAGradientLayer *wash = [CAGradientLayer layer];
        wash.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.06].CGColor, (id)[UIColor colorWithWhite:0 alpha:0.25].CGColor];
        wash.startPoint = CGPointMake(0, 0);
        wash.endPoint = CGPointMake(1, 1);
        wash.cornerRadius = 12;
        [picture.layer addSublayer:wash];
    }
    if (visualiser) {
        // Two crests, as the visualiser draws them.
        for (NSUInteger k = 0; k < 2; k++) {
            CAShapeLayer *hill = [CAShapeLayer layer];
            UIBezierPath *path = [UIBezierPath bezierPath];
            CGFloat base = k ? 0.78 : 0.88, crest = k ? 0.46 : 0.60;
            [path moveToPoint:CGPointMake(0, kCardHeight * base)];
            [path addQuadCurveToPoint:CGPointMake(kCardWidth * 0.5, kCardHeight * base) controlPoint:CGPointMake(kCardWidth * 0.25, kCardHeight * crest)];
            [path addQuadCurveToPoint:CGPointMake(kCardWidth, kCardHeight * base) controlPoint:CGPointMake(kCardWidth * 0.75, kCardHeight * (crest + 0.08))];
            [path addLineToPoint:CGPointMake(kCardWidth, kCardHeight)];
            [path addLineToPoint:CGPointMake(0, kCardHeight)];
            [path closePath];
            hill.path = path.CGPath;
            hill.fillColor = [UIColor colorWithWhite:1 alpha:k ? 0.16 : 0.22].CGColor;
            [picture.layer addSublayer:hill];
        }
    }
    if (aurora) {
        // The curtains: three vertical washes of light over black.
        card.backgroundColor = UIColor.blackColor;
        for (NSUInteger k = 0; k < 3; k++) {
            CAGradientLayer *curtain = [CAGradientLayer layer];
            NSArray<UIColor *> *tints = @[SGColorRGB(0xE62B90), SGColorRGB(0x7E5BE6), SGColorRGB(0x2BD9E6)];
            curtain.colors = @[(id)[tints[k] colorWithAlphaComponent:0.55].CGColor, (id)[tints[k] colorWithAlphaComponent:0].CGColor];
            curtain.startPoint = CGPointMake(0.5, 1);
            curtain.endPoint = CGPointMake(0.5, 0.2);
            curtain.frame = CGRectMake(kCardWidth * (0.08 + 0.3 * k), 0, kCardWidth * 0.34, kCardHeight);
            [picture.layer addSublayer:curtain];
        }
    }
    if (!aurora) card.backgroundColor = SGCardBackground();
    [picture setNeedsLayout];
}

- (void)tapped:(UIControl *)card {
    _selected = card.tag;
    [self setSelected:_selected];
    if (_picked) _picked(card.tag);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    _run.frame = self.bounds;
    CGFloat x = kSide;
    for (UIView *card in _cards) {
        card.frame = CGRectMake(x, 8, kCardWidth, kCardHeight);
        UIView *picture = [card viewWithTag:1];
        picture.frame = CGRectMake(0, 0, kCardWidth, kCardHeight - 22);
        for (CALayer *layer in picture.layer.sublayers) layer.frame = picture.bounds;
        [card viewWithTag:2].frame = CGRectMake(-4, kCardHeight - 20, kCardWidth + 8, 16);
        x += kCardWidth + kGap;
    }
    _run.contentSize = CGSizeMake(MAX(width, x - kGap + kSide), height);
    _run.contentInset = UIEdgeInsetsMake(0, 0, 0, kSide);
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(kSide * 2 + _cards.count * (kCardWidth + kGap), kCardHeight + 16);
}

@end
