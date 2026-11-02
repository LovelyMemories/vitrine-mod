#import "SGRAurora.h"
#import <math.h>
#import "Core/SGCore.h"

// Six curtains of light, their edges soft, over black.
static const NSInteger kAuroraCurtains = 6;

@implementation SGRauroraLayer {
    CALayer *_base;                                   // black: the field's color must not wash the light out
    NSMutableArray<CALayer *> *_curtains;
    NSMutableArray<CAGradientLayer *> *_masks;
    NSMutableArray<NSArray<CAGradientLayer *> *> *_colors;
    CAGradientLayer *_horizon;
    NSArray<UIColor *> *_palette;
    CGSize _placedFor;
    BOOL _moving;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.masksToBounds = YES;

    // An aurora is light on darkness. The field paints its own color under everything, so the only way to get
    // depth is to stop it here.
    _base = [CALayer layer];
    _base.backgroundColor = UIColor.blackColor.CGColor;
    [self addSublayer:_base];

    _curtains = [NSMutableArray arrayWithCapacity:kAuroraCurtains];
    _masks = [NSMutableArray arrayWithCapacity:kAuroraCurtains];
    _colors = [NSMutableArray arrayWithCapacity:kAuroraCurtains];
    for (NSInteger i = 0; i < kAuroraCurtains; i++) {
        // A curtain is two colors in one place behind one mask: their opacities cross, so the light changes
        // hue where it stands instead of the whole sheet sliding about.
        CALayer *curtain = [CALayer layer];
        CAGradientLayer *mask = [self edgeMask];
        curtain.mask = mask;

        CAGradientLayer *first = [self curtainLayer];
        CAGradientLayer *second = [self curtainLayer];
        [curtain addSublayer:first];
        [curtain addSublayer:second];
        [self addSublayer:curtain];

        [_curtains addObject:curtain];
        [_masks addObject:mask];
        [_colors addObject:@[first, second]];
    }

    // The foot of the sky: the light pooling at the bottom edge, where a curtain is brightest.
    _horizon = [CAGradientLayer layer];
    _horizon.type = kCAGradientLayerAxial;
    _horizon.startPoint = CGPointMake(0.5, 1);
    _horizon.endPoint = CGPointMake(0.5, 0);
    [self addSublayer:_horizon];
    return self;
}

// A curtain: bright at its foot, thinning out upward, and gone before the top of the screen.
- (CAGradientLayer *)curtainLayer {
    CAGradientLayer *layer = [CAGradientLayer layer];
    layer.type = kCAGradientLayerAxial;
    layer.startPoint = CGPointMake(0.5, 1);
    layer.endPoint = CGPointMake(0.5, 0);
    layer.locations = @[@0, @0.35, @1];
    layer.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.95].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0.45].CGColor,
                     (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    return layer;
}

// Soft left and right edges: a curtain has no sides, only a middle.
- (CAGradientLayer *)edgeMask {
    CAGradientLayer *mask = [CAGradientLayer layer];
    mask.type = kCAGradientLayerAxial;
    mask.startPoint = CGPointMake(0, 0.5);
    mask.endPoint = CGPointMake(1, 0.5);
    mask.locations = @[@0, @0.5, @1];
    mask.colors = @[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:1].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    return mask;
}

static NSArray *curtainColors(UIColor *color) {
    return @[(id)[color colorWithAlphaComponent:1].CGColor,
             (id)[color colorWithAlphaComponent:0.55].CGColor,
             (id)[color colorWithAlphaComponent:0].CGColor];
}

// The palette keeps a cover's darker ends -- for a field that is right, and on black it is nearly invisible. A
// curtain is light, so its color is lifted hard: saturation up, brightness up, and never below 0.85.
static UIColor *lightOf(UIColor *color) {
    CGFloat h = 0, s = 0, b = 0, a = 1;
    if (![color getHue:&h saturation:&s brightness:&b alpha:&a]) return [UIColor colorWithWhite:0.95 alpha:1];
    return [UIColor colorWithHue:h saturation:MIN(1, s * 1.4) brightness:MIN(1, MAX(0.85, b * 1.9)) alpha:1];
}

- (void)setColors:(NSArray<UIColor *> *)colors animated:(BOOL)animated {
    _palette = [colors copy];
    NSUInteger count = colors.count;
    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    for (NSInteger i = 0; i < kAuroraCurtains; i++) {
        UIColor *first = count ? lightOf(colors[(NSUInteger)i % count]) : [UIColor colorWithWhite:0.92 alpha:1];
        // Four along the palette, so neighbouring curtains are never the same light.
        UIColor *second = count ? lightOf(colors[((NSUInteger)i + 4) % count]) : [UIColor colorWithWhite:0.8 alpha:1];
        NSArray<CAGradientLayer *> *pair = _colors[(NSUInteger)i];
        pair[0].colors = curtainColors(first);
        pair[1].colors = curtainColors(second);
    }
    UIColor *foot = count ? lightOf(colors.firstObject) : [UIColor colorWithWhite:0.9 alpha:1];
    _horizon.colors = @[(id)[foot colorWithAlphaComponent:0.6].CGColor, (id)[foot colorWithAlphaComponent:0].CGColor];
    [CATransaction commit];
    [self setNeedsLayout];
}

- (void)setMoving:(BOOL)moving {
    if (moving == _moving) return;
    _moving = moving;
    if (moving) {
        [self placeFor:self.bounds.size];
        [self addAnimations];
    } else {
        [self removeAnimations];
    }
}

- (void)layoutSublayers {
    [super layoutSublayers];
    [self placeFor:self.bounds.size];
}

- (void)placeFor:(CGSize)size {
    if (size.width < 1 || size.height < 1) return;
    BOOL resized = !CGSizeEqualToSize(_placedFor, size);
    _placedFor = size;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _base.frame = CGRectMake(0, 0, size.width, size.height);
    _horizon.frame = CGRectMake(0, size.height * 0.70, size.width, size.height * 0.30);

    CGFloat width = size.width * 0.44, height = size.height * 1.3;
    for (NSInteger i = 0; i < kAuroraCurtains; i++) {
        CALayer *curtain = _curtains[(NSUInteger)i];
        CGFloat x = size.width * (-0.08 + 0.235 * i);
        curtain.bounds = CGRectMake(0, 0, width, height);
        if (resized || !_moving) curtain.position = CGPointMake(x, size.height * 0.56);
        _masks[(NSUInteger)i].frame = curtain.bounds;
        for (CAGradientLayer *layer in _colors[(NSUInteger)i]) layer.frame = curtain.bounds;
    }
    [CATransaction commit];
    if (_moving && resized) [self addAnimations];
}

- (void)addAnimations {
    if (_placedFor.width < 1) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGSize size = _placedFor;
    for (NSInteger i = 0; i < kAuroraCurtains; i++) {
        CALayer *curtain = _curtains[(NSUInteger)i];
        NSArray<CAGradientLayer *> *pair = _colors[(NSUInteger)i];

        // Each curtain sways a little, at its own pace, and never far: the light breathes, it does not travel.
        CGFloat sway = size.width * 0.055 * (i % 2 ? -1 : 1);
        CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"position.x"];
        drift.fromValue = @(curtain.position.x);
        drift.toValue = @(curtain.position.x + sway);
        drift.duration = 13 + i * 2.7;
        drift.autoreverses = YES;
        drift.repeatCount = HUGE_VALF;
        drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [curtain addAnimation:drift forKey:@"aurora.sway"];

        // The two colors cross while the light stands still: the hue drifts through the cover's palette.
        CFTimeInterval turn = 9 + i * 1.4;
        [self fade:pair[0] from:0.9 to:0.25 duration:turn offset:0 key:@"aurora.hue"];
        [self fade:pair[1] from:0.25 to:0.9 duration:turn offset:turn key:@"aurora.hue"];
    }
    [CATransaction commit];
}

- (void)fade:(CALayer *)layer from:(CGFloat)from to:(CGFloat)to duration:(CFTimeInterval)duration
      offset:(CFTimeInterval)offset key:(NSString *)key {
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @(from);
    fade.toValue = @(to);
    fade.duration = duration;
    fade.autoreverses = YES;
    fade.repeatCount = HUGE_VALF;
    fade.timeOffset = offset;
    fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:fade forKey:key];
}

- (void)removeAnimations {
    for (NSInteger i = 0; i < kAuroraCurtains; i++) {
        [_curtains[(NSUInteger)i] removeAnimationForKey:@"aurora.sway"];
        for (CAGradientLayer *layer in _colors[(NSUInteger)i]) [layer removeAnimationForKey:@"aurora.hue"];
    }
}

@end
