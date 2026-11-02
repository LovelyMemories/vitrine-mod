#import "SGRAurora.h"
#import <math.h>
#import "Core/SGCore.h"

// Seven pools, large enough to overlap and leave no edge of their own, and one band of light crossing them.
static const NSInteger kAuroraPools = 7;
// Three colors to a pool, their opacities a third of a cycle apart: the pool runs A to B to C and round again,
// which is the shimmer. Two would only ever swap places.
static const NSInteger kAuroraColorsPerPool = 3;

@implementation SGRauroraLayer {
    NSMutableArray<NSArray<CAGradientLayer *> *> *_pools;
    CAGradientLayer *_sweep;
    NSArray<UIColor *> *_colors;
    CGSize _placedFor;
    BOOL _moving;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.masksToBounds = YES;

    _pools = [NSMutableArray arrayWithCapacity:kAuroraPools];
    for (NSInteger i = 0; i < kAuroraPools; i++) {
        NSMutableArray<CAGradientLayer *> *pool = [NSMutableArray arrayWithCapacity:kAuroraColorsPerPool];
        for (NSInteger k = 0; k < kAuroraColorsPerPool; k++) {
            CAGradientLayer *layer = [self softBlob];
            [self addSublayer:layer];
            [pool addObject:layer];
        }
        [_pools addObject:pool];
    }

    // The light: a narrow band of white, turned across the screen and carried over it once in a while.
    _sweep = [CAGradientLayer layer];
    _sweep.type = kCAGradientLayerAxial;
    _sweep.startPoint = CGPointMake(0, 0.5);
    _sweep.endPoint = CGPointMake(1, 0.5);
    _sweep.locations = @[@0, @0.42, @0.58, @1];
    _sweep.colors = @[(id)[UIColor colorWithWhite:1 alpha:0].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.16].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0.16].CGColor,
                      (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    [self addSublayer:_sweep];
    return self;
}

- (CAGradientLayer *)softBlob {
    CAGradientLayer *blob = [CAGradientLayer layer];
    // A radial gradient is the soft edge: opaque at its middle, clear at its rim, so no blur is needed.
    blob.type = kCAGradientLayerRadial;
    blob.startPoint = CGPointMake(0.5, 0.5);
    blob.endPoint = CGPointMake(1, 1);
    blob.locations = @[@0, @0.55, @1];
    blob.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.8].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0.35].CGColor,
                    (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    return blob;
}

- (void)setColors:(NSArray<UIColor *> *)colors animated:(BOOL)animated {
    _colors = [colors copy];
    NSUInteger count = colors.count;
    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    for (NSInteger i = 0; i < kAuroraPools; i++) {
        NSArray<CAGradientLayer *> *pool = _pools[(NSUInteger)i];
        for (NSInteger k = 0; k < kAuroraColorsPerPool; k++) {
            UIColor *color = count ? colors[((NSUInteger)i + (NSUInteger)k * 2) % count] : [UIColor colorWithWhite:1 alpha:0.4];
            CAGradientLayer *layer = pool[(NSUInteger)k];
            layer.colors = @[(id)[color colorWithAlphaComponent:0.85].CGColor,
                             (id)[color colorWithAlphaComponent:0.35].CGColor,
                             (id)[color colorWithAlphaComponent:0].CGColor];
        }
    }
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

// The pools sit on a wide ring and are far larger than their spacing, so what the eye gets is one field of
// light with no circle to count. The sweep is a band taller than the screen, turned across it.
- (void)placeFor:(CGSize)size {
    if (size.width < 1 || size.height < 1) return;
    BOOL resized = !CGSizeEqualToSize(_placedFor, size);
    _placedFor = size;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSInteger i = 0; i < kAuroraPools; i++) {
        CGFloat phase = (CGFloat)i / kAuroraPools * (CGFloat)M_PI * 2 + 0.4;
        // Golden-angle spread of the radii keeps the ring from reading as a ring.
        CGFloat radius = size.width * (0.24 + 0.05 * (i % 3));
        CGPoint at = CGPointMake(size.width / 2 + cos(phase) * radius * 1.15,
                                 size.height / 2 + sin(phase) * radius * 1.5);
        CGFloat side = size.width * (1.25 + 0.22 * (i % 4));
        for (CAGradientLayer *layer in _pools[(NSUInteger)i]) {
            layer.bounds = CGRectMake(0, 0, side, side);
            if (resized || !_moving) layer.position = at;
        }
    }
    CGFloat bandWidth = size.width * 0.55;
    _sweep.bounds = CGRectMake(0, 0, bandWidth, size.height * 1.9);
    _sweep.anchorPoint = CGPointMake(0.5, 0.5);
    _sweep.position = CGPointMake(size.width * 0.5, size.height * 0.5);
    _sweep.transform = CATransform3DMakeRotation(-20 * (CGFloat)M_PI / 180, 0, 0, 1);
    [CATransaction commit];
    if (_moving && resized) [self addAnimations];
}

- (void)addAnimations {
    if (_placedFor.width < 1) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGSize size = _placedFor;
    for (NSInteger i = 0; i < kAuroraPools; i++) {
        NSArray<CAGradientLayer *> *pool = _pools[(NSUInteger)i];
        // A pool's own pace; its three colors take turns a third of that apart, so one is always rising as
        // another falls and the pool never dips to nothing.
        CFTimeInterval period = 11 + i * 1.6;
        for (NSInteger k = 0; k < kAuroraColorsPerPool; k++) {
            CAGradientLayer *layer = pool[(NSUInteger)k];
            CABasicAnimation *turn = [CABasicAnimation animationWithKeyPath:@"opacity"];
            turn.fromValue = @(0.9);
            turn.toValue = @(0.15);
            turn.duration = period;
            turn.autoreverses = YES;
            turn.repeatCount = HUGE_VALF;
            turn.timeOffset = (CFTimeInterval)k * period * 2 / kAuroraColorsPerPool;
            turn.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            [layer addAnimation:turn forKey:@"aurora.turn"];

            [self drift:layer duration:34 + i * 7];
        }
    }
    // The band crosses the screen every so often and comes back the other way: the widest, slowest glint.
    CAKeyframeAnimation *cross = [CAKeyframeAnimation animationWithKeyPath:@"position.x"];
    cross.values = @[@(size.width * -0.4), @(size.width * 1.4), @(size.width * -0.4)];
    cross.keyTimes = @[@0, @0.5, @1];
    cross.duration = 44;
    cross.repeatCount = HUGE_VALF;
    cross.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_sweep addAnimation:cross forKey:@"aurora.sweep"];
    [CATransaction commit];
}

- (void)drift:(CALayer *)layer duration:(CFTimeInterval)duration {
    CGSize size = _placedFor;
    CGPoint from = layer.position;
    CGPoint to = CGPointMake(size.width - from.x, size.height - from.y);
    CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"position"];
    drift.fromValue = [NSValue valueWithCGPoint:from];
    drift.toValue = [NSValue valueWithCGPoint:to];
    drift.duration = duration;
    drift.autoreverses = YES;
    drift.repeatCount = HUGE_VALF;
    drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:drift forKey:@"aurora.drift"];
}

- (void)removeAnimations {
    for (NSArray<CAGradientLayer *> *pool in _pools) {
        for (CAGradientLayer *layer in pool) {
            [layer removeAnimationForKey:@"aurora.turn"];
            [layer removeAnimationForKey:@"aurora.drift"];
        }
    }
    [_sweep removeAnimationForKey:@"aurora.sweep"];
}

@end
