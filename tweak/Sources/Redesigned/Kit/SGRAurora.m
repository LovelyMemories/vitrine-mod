#import "SGRAurora.h"
#import <math.h>
#import "Core/SGCore.h"

// Five pools of light, and four specular glints over them.
static const NSInteger kAuroraBlobs = 5;
static const NSInteger kAuroraGlints = 4;

@implementation SGRauroraLayer {
    NSMutableArray<NSArray<CAGradientLayer *> *> *_blobs;   // each pool: two colors that take turns
    NSMutableArray<CAGradientLayer *> *_glints;
    NSArray<UIColor *> *_colors;
    CGSize _placedFor;
    BOOL _moving;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    self.masksToBounds = YES;
    _blobs = [NSMutableArray arrayWithCapacity:kAuroraBlobs];
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        // Two gradients in the same place, their opacities crossing: the pool changes color without anything
        // being re-rendered, which is the shimmer. A single gradient could not do it.
        CAGradientLayer *first = [self blob];
        CAGradientLayer *second = [self blob];
        [self addSublayer:second];
        [self addSublayer:first];
        [_blobs addObject:@[first, second]];
    }
    _glints = [NSMutableArray arrayWithCapacity:kAuroraGlints];
    for (NSInteger i = 0; i < kAuroraGlints; i++) {
        CAGradientLayer *glint = [self blob];
        [self addSublayer:glint];
        [_glints addObject:glint];
    }
    return self;
}

- (CAGradientLayer *)blob {
    CAGradientLayer *blob = [CAGradientLayer layer];
    // A radial gradient is the soft edge: opaque at its middle, clear at its rim, so no blur is needed.
    blob.type = kCAGradientLayerRadial;
    blob.startPoint = CGPointMake(0.5, 0.5);
    blob.endPoint = CGPointMake(1, 1);
    blob.locations = @[@0, @1];
    blob.colors = @[(id)[UIColor colorWithWhite:1 alpha:0.85].CGColor, (id)[UIColor colorWithWhite:1 alpha:0].CGColor];
    return blob;
}

// The same hue lifted toward white: a glint is the color catching light, not a second color.
static UIColor *glintColor(UIColor *color) {
    CGFloat h = 0, s = 0, b = 0, a = 1;
    if (![color getHue:&h saturation:&s brightness:&b alpha:&a]) return [UIColor colorWithWhite:1 alpha:0.8];
    return [UIColor colorWithHue:h saturation:MIN(0.35, s * 0.4) brightness:1 alpha:1];
}

- (void)setColors:(NSArray<UIColor *> *)colors animated:(BOOL)animated {
    _colors = [colors copy];
    [CATransaction begin];
    [CATransaction setDisableActions:!animated];
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        NSArray<CAGradientLayer *> *pair = _blobs[(NSUInteger)i];
        UIColor *first = colors.count ? colors[(NSUInteger)i % colors.count] : [UIColor colorWithWhite:1 alpha:0.5];
        // The second pool is two steps along the palette, so the two are never the same color and the crossing
        // always reads as a change rather than as a pulse.
        UIColor *second = colors.count ? colors[((NSUInteger)i + 2) % colors.count] : [UIColor colorWithWhite:1 alpha:0.35];
        [self paint:pair[0] color:first];
        [self paint:pair[1] color:second];
    }
    for (NSInteger i = 0; i < kAuroraGlints; i++) {
        UIColor *base = colors.count ? colors[(NSUInteger)i % colors.count] : [UIColor colorWithWhite:1 alpha:0.8];
        [self paint:_glints[(NSUInteger)i] color:glintColor(base)];
    }
    [CATransaction commit];
    [self setNeedsLayout];
}

- (void)paint:(CAGradientLayer *)blob color:(UIColor *)color {
    // Kept at a share of the color's own alpha: an aurora is light, never a solid disc.
    blob.colors = @[(id)[color colorWithAlphaComponent:0.85].CGColor, (id)[color colorWithAlphaComponent:0].CGColor];
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

// Where each pool sits at rest and where it drifts to: two points mirrored about the middle, so the whole
// thing breathes out and back rather than travelling anywhere. The glints ride a tighter ring at their own
// pace, which is what keeps the surface from moving as one piece.
- (void)placeFor:(CGSize)size {
    if (size.width < 1 || size.height < 1) return;
    BOOL resized = !CGSizeEqualToSize(_placedFor, size);
    _placedFor = size;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    for (NSInteger i = 0; i < kAuroraBlobs; i++) {
        CGFloat phase = (CGFloat)i / kAuroraBlobs * (CGFloat)M_PI * 2;
        CGFloat radius = size.width * (0.20 + 0.05 * (i % 2));
        CGPoint at = CGPointMake(size.width / 2 + cos(phase) * radius,
                                 size.height / 2 + sin(phase) * radius * 0.7);
        CGFloat side = size.width * (0.95 + 0.18 * (i % 3));
        for (CAGradientLayer *blob in _blobs[(NSUInteger)i]) {
            blob.bounds = CGRectMake(0, 0, side, side);
            if (resized || !_moving) blob.position = at;
        }
    }
    for (NSInteger i = 0; i < kAuroraGlints; i++) {
        CGFloat phase = (CGFloat)i / kAuroraGlints * (CGFloat)M_PI * 2 + 0.6;
        CGFloat radius = size.width * 0.30;
        CGPoint at = CGPointMake(size.width / 2 + cos(phase) * radius,
                                 size.height / 2 + sin(phase) * radius * 0.55);
        CGFloat side = size.width * 0.16;
        CAGradientLayer *glint = _glints[(NSUInteger)i];
        glint.bounds = CGRectMake(0, 0, side, side);
        if (resized || !_moving) glint.position = at;
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
        CGFloat phase = (CGFloat)i / kAuroraBlobs * (CGFloat)M_PI * 2;
        CGFloat radius = size.width * (0.20 + 0.05 * (i % 2));
        CGPoint from = CGPointMake(size.width / 2 + cos(phase) * radius,
                                   size.height / 2 + sin(phase) * radius * 0.7);
        CGPoint to = CGPointMake(size.width - from.x, size.height - from.y);
        NSArray<CAGradientLayer *> *pair = _blobs[(NSUInteger)i];
        for (NSInteger k = 0; k < 2; k++) {
            CAGradientLayer *blob = pair[(NSUInteger)k];
            CGFloat offset = k * 6.5;   // the two colors of one pool cross, rather than pulse together
            // The same path and pace, so the two colors stay one pool; only their opacities are offset.
            [self drift:blob from:from to:to duration:26 + i * 6 key:@"aurora.drift"];
            // Their opacities run in antiphase: as one dims the other takes over, and the pool changes color.
            [self breathe:blob from:(k == 0 ? 0.85 : 0.35) to:(k == 0 ? 0.35 : 0.85)
                 duration:12 + i * 2.5 + offset key:@"aurora.shimmer"];
        }
    }
    for (NSInteger i = 0; i < kAuroraGlints; i++) {
        CGFloat phase = (CGFloat)i / kAuroraGlints * (CGFloat)M_PI * 2 + 0.6;
        CGFloat radius = size.width * 0.30;
        CGPoint from = CGPointMake(size.width / 2 + cos(phase) * radius,
                                   size.height / 2 + sin(phase) * radius * 0.55);
        CGPoint to = CGPointMake(size.width - from.x, size.height - from.y);
        CAGradientLayer *glint = _glints[(NSUInteger)i];
        [self drift:glint from:from to:to duration:14 + i * 3.2 key:@"aurora.glint.drift"];
        [self breathe:glint from:0.10 to:0.75 duration:5.5 + i * 1.3 key:@"aurora.glint.glow"];
    }
    [CATransaction commit];
}

- (void)drift:(CALayer *)layer from:(CGPoint)from to:(CGPoint)to duration:(CFTimeInterval)duration key:(NSString *)key {
    CABasicAnimation *drift = [CABasicAnimation animationWithKeyPath:@"position"];
    drift.fromValue = [NSValue valueWithCGPoint:from];
    drift.toValue = [NSValue valueWithCGPoint:to];
    drift.duration = duration;
    drift.autoreverses = YES;
    drift.repeatCount = HUGE_VALF;
    drift.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:drift forKey:key];
}

- (void)breathe:(CALayer *)layer from:(CGFloat)from to:(CGFloat)to duration:(CFTimeInterval)duration key:(NSString *)key {
    CABasicAnimation *breathe = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breathe.fromValue = @(from);
    breathe.toValue = @(to);
    breathe.duration = duration;
    breathe.autoreverses = YES;
    breathe.repeatCount = HUGE_VALF;
    breathe.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [layer addAnimation:breathe forKey:key];
}

- (void)removeAnimations {
    for (NSArray<CAGradientLayer *> *pair in _blobs) {
        for (CAGradientLayer *blob in pair) {
            [blob removeAnimationForKey:@"aurora.drift"];
            [blob removeAnimationForKey:@"aurora.shimmer"];
        }
    }
    for (CAGradientLayer *glint in _glints) {
        [glint removeAnimationForKey:@"aurora.glint.drift"];
        [glint removeAnimationForKey:@"aurora.glint.glow"];
    }
}

@end
