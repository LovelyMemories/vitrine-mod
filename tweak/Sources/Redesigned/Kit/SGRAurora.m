#import "SGRAurora.h"
#import <math.h>
#import "Core/SGCore.h"

// Five blobs: enough that no two edges line up, few enough to read as light rather than as a pattern.
static const NSInteger kAuroraBlobs = 5;

@implementation SGRauroraLayer {
    NSMutableArray<CAGradientLayer *> *_blobs;
    NSArray<UIColor *> *_colors;
    CGSize _placedFor;
    BOOL _moving;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.masksToBounds = YES;
    _blobs = [NSMutableArray arrayWithCapacity:kAuroraBlobs];
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        CAGradientLayer *blob = [CAGradientLayer layer];
        // A radial gradient is the soft edge: opaque at its middle, clear at its rim, so no blur is needed.
        blob.type = kCAGradientLayerRadial;
        blob.startPoint = CGPointMake(0.5, 0.5);
        blob.endPoint = CGPointMake(1, 1);
        blob.locations = @[@0, @1];
        blob.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.85].CGColor, (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
        [self addSublayer:blob];
        [_blobs addObject:blob];
    }
    return self;
}

- (void)setColors:(NSArray<UIColor *> *)colors animated:(BOOL)animated {
    _colors = [colors copy];
    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        UIColor *color = colors.count ? colors[(NSUInteger)i % colors.count] : [UIColor colorWithWhite:1 alpha:0.5];
        CAGradientLayer *blob = _blobs[(NSUInteger)i];
        // Kept at a share of the color's own alpha: an aurora is light, never a solid disc.
        blob.colors = @[(id)[color colorWithAlphaComponent:0.85].CGColor, (id)[color colorWithAlphaComponent:0].CGColor];
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

// Where each blob sits at rest, and where it drifts to: two points mirrored about the middle, so the whole
// thing breathes out and back rather than travelling anywhere.
- (void)placeFor:(CGSize)size {
    if (size.width < 1 || size.height < 1) return;
    BOOL resized = !CGSizeEqualToSize(_placedFor, size);
    _placedFor = size;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        CAGradientLayer *blob = _blobs[(NSUInteger)i];
        CGFloat phase = (CGFloat)i / kAuroraBlobs * (CGFloat)M_PI * 2;
        CGFloat radius = size.width * (0.20 + 0.05 * (i % 2));
        CGPoint at = CGPointMake(size.width / 2 + cos(phase) * radius,
                                 size.height / 2 + sin(phase) * radius * 0.7);
        CGFloat side = size.width * (0.95 + 0.18 * (i % 3));
        blob.bounds = CGRectMake(0, 0, side, side);
        if (resized || !_moving) blob.position = at;
    }
    [CATransaction commit];
    if (_moving && resized) [self addAnimations];
}

- (void)addAnimations {
    if (_placedFor.width < 1) return;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGSize size = _placedFor;
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        CAGradientLayer *blob = _blobs[(NSUInteger)i];
        CGFloat phase = (CGFloat)i / kAuroraBlobs * (CGFloat)M_PI * 2;
        CGFloat radius = size.width * (0.20 + 0.05 * (i % 2));
        CGPoint from = CGPointMake(size.width / 2 + cos(phase) * radius,
                                   size.height / 2 + sin(phase) * radius * 0.7);
        CGPoint to = CGPointMake(size.width - from.x, size.height - from.y);

        CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"position"];
        drift.fromValue = [NSValue valueWithCGPoint:from];
        drift.toValue = [NSValue valueWithCGPoint:to];
        drift.duration = 26 + i * 6;
        drift.autoreverses = YES;
        drift.repeatCount = HUGE_VALF;
        drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [blob addAnimation:drift forKey:@"aurora.drift"];

        CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"opacity"];
        breathe.fromValue = @(0.55);
        breathe.toValue = @(0.9);
        breathe.duration = 9 + i * 1.7;
        breathe.autoreverses = YES;
        breathe.repeatCount = HUGE_VALF;
        breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [blob addAnimation:breathe forKey:@"aurora.breathe"];
    }
    [CATransaction commit];
}

- (void)removeAnimations {
    for (CAGradientLayer *blob in _blobs) {
        [blob removeAnimationForKey:@"aurora.drift"];
        [blob removeAnimationForKey:@"aurora.breathe"];
    }
}

@end
