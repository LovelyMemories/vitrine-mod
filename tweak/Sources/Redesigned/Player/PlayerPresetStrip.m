#import "PlayerPresetStrip.h"
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRFluid.h"
#import "Settings/SGPageStyle.h"

static const CGFloat kCardWidth = 74, kCardHeight = 122, kGap = 10, kSide = 16;

@implementation SGRFluidPresetStrip {
    NSArray<NSString *> *_names;
    void (^_picked)(NSInteger index);
    NSMutableArray<UIView *> *_cards;
}

- (instancetype)initWithFrame:(CGRect)frame names:(NSArray<NSString *> *)names picked:(void (^)(NSInteger))picked {
    if (!(self = [super initWithFrame:frame])) return nil;
    _names = [names copy];
    _picked = [picked copy];
    _cards = [NSMutableArray array];
    self.backgroundColor = SGCardBackground();
    self.layer.cornerRadius = 16;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.clipsToBounds = NO;

    for (NSUInteger i = 0; i < names.count; i++) {
        UIControl *card = [UIControl new];
        card.tag = (NSInteger)i;
        [card addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        card.accessibilityLabel = names[i];
        card.layer.cornerRadius = 16;
        card.layer.cornerCurve = kCACornerCurveContinuous;

        UIView *art = [UIView new];
        art.tag = 1;
        art.userInteractionEnabled = NO;
        art.layer.cornerRadius = 12;
        art.layer.cornerCurve = kCACornerCurveContinuous;
        art.clipsToBounds = YES;
        [card addSubview:art];

        UILabel *title = [UILabel new];
        title.tag = 2;
        title.text = SGLocalized(names[i]);
        title.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        title.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        title.textAlignment = NSTextAlignmentCenter;
        [card addSubview:title];

        [self addSubview:card];
        [_cards addObject:card];
    }
    return self;
}

- (void)setColors:(NSArray<UIColor *> *)colors {
    _colors = [colors copy];
    for (NSUInteger i = 0; i < _cards.count; i++) [self paint:_cards[i] index:i];
}

// The card's look, from the preset's own numbers: the more warp and brightness a preset has, the more the colors
// spread and the lighter the card reads. Four radial washes in the place the field puts them.
- (void)paint:(UIView *)card index:(NSUInteger)index {
    UIView *art = [card viewWithTag:1];
    for (CALayer *layer in [art.layer.sublayers copy]) [layer removeFromSuperlayer];
    art.backgroundColor = UIColor.blackColor;
    NSArray<UIColor *> *source = _colors.count ? _colors : @[SGColorRGB(0x3050D0), SGColorRGB(0xC03A80), SGColorRGB(0xE07030)];
    NSInteger speed = SGRFluidPresetValueAt((NSInteger)index, SGRFluidSpeed), warp = SGRFluidPresetValueAt((NSInteger)index, SGRFluidWarp);
    NSInteger saturation = SGRFluidPresetValueAt((NSInteger)index, SGRFluidSaturation), brightness = SGRFluidPresetValueAt((NSInteger)index, SGRFluidBrightness);
    CGFloat spread = 0.30 + 0.25 * (warp / 100.0), gain = 0.55 + 0.45 * (brightness / 140.0), vivid = 0.6 + 0.4 * (saturation / 250.0);
    CGPoint spots[4] = {{0.30, 0.28}, {0.72, 0.34}, {0.42, 0.74}, {0.80, 0.82}};
    for (NSUInteger k = 0; k < 4; k++) {
        UIColor *color = source[(index + k) % source.count];
        CAGradientLayer *wash = [CAGradientLayer layer];
        wash.type = kCAGradientLayerRadial;
        wash.startPoint = CGPointMake(spots[k].x, spots[k].y);
        wash.endPoint = CGPointMake(spots[k].x + spread, spots[k].y + spread);
        wash.colors = @[(id)[color colorWithAlphaComponent:0.9 * gain * vivid].CGColor, (id)[color colorWithAlphaComponent:0].CGColor];
        wash.locations = @[@0, @1];
        [art.layer addSublayer:wash];
    }
    // The speed is caught as a smear: a fast preset is drawn with a lighter band across it.
    if (speed >= 200) {
        CAGradientLayer *smear = [CAGradientLayer layer];
        smear.colors = @[(id)[UIColor colorWithWhite:1 alpha:0].CGColor, (id)[UIColor colorWithWhite:1 alpha:0.14].CGColor,
                         (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
        smear.startPoint = CGPointMake(0, 0);
        smear.endPoint = CGPointMake(1, 1);
        [art.layer addSublayer:smear];
    }
    [art setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset = kSide, x = inset;
    for (UIView *card in _cards) {
        card.frame = CGRectMake(x, 14, kCardWidth, kCardHeight);
        UIView *art = [card viewWithTag:1];
        art.frame = CGRectMake(0, 0, kCardWidth, kCardHeight - 20);
        for (CALayer *layer in art.layer.sublayers) layer.frame = art.bounds;
        UILabel *title = [card viewWithTag:2];
        title.frame = CGRectMake(-4, CGRectGetMaxY(art.frame) + 3, kCardWidth + 8, 16);
        x += kCardWidth + kGap;
    }
    NSInteger current = SGRFluidCurrentPreset();
    for (UIView *card in _cards) {
        BOOL on = card.tag == current;
        card.layer.borderWidth = on ? 2 : 0;
        card.layer.borderColor = SGGreen().CGColor;
        UIView *art = [card viewWithTag:1];
        art.frame = CGRectInset(art.frame, on ? 2 : 0, on ? 2 : 0);
    }
}

- (void)tapped:(UIControl *)card {
    if (_picked) _picked(card.tag);
    [self setNeedsLayout];
}

- (CGSize)intrinsicContentSize {
    return CGSizeMake(kSide * 2 + _cards.count * (kCardWidth + kGap), kCardHeight + 30);
}

@end
