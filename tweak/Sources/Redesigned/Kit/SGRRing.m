#import "SGRRing.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

static const CGFloat kRingWidth = 1.5;          // the line itself
static const CFTimeInterval kRingTurn = 8;      // seconds for the line to go round once

// Around a capsule the way a conic gradient runs, starting and ending on the same pink so a turn has no seam.
static NSArray *ringRainbow(void) {
    static NSArray *colors;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *list = [NSMutableArray array];
        for (NSNumber *rgb in @[@0xFF375F, @0xFF9F0A, @0xFFD60A, @0x30D158, @0x64D2FF, @0x0A84FF, @0xBF5AF2, @0xFF375F]) {
            uint32_t v = rgb.unsignedIntValue;
            [list addObject:(id)[UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0 green:((v >> 8) & 0xFF) / 255.0
                                                 blue:(v & 0xFF) / 255.0 alpha:1].CGColor];
        }
        colors = list;
    });
    return colors;
}

// One band: a holder masked to a stroke of `width`, and inside it the rainbow, turning. The mask is on the holder
// and not on the gradient, or the turn would carry the mask round with it and the ring would sweep the screen.
static void bandIn(UIView *rim, CGFloat width, CGFloat alpha, CFTimeInterval turn, BOOL backwards) {
    CALayer *holder = [CALayer layer];
    CAShapeLayer *stroke = [CAShapeLayer layer];
    stroke.fillColor = UIColor.clearColor.CGColor;
    stroke.strokeColor = UIColor.blackColor.CGColor;
    stroke.lineWidth = width;
    holder.mask = stroke;

    CAGradientLayer *band = [CAGradientLayer layer];
    band.type = kCAGradientLayerConic;
    band.colors = ringRainbow();
    band.startPoint = CGPointMake(0.5, 0.5);
    band.endPoint = CGPointMake(0.5, 0);
    band.opacity = alpha;
    [holder addSublayer:band];

    CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    spin.fromValue = backwards ? @(2 * M_PI) : @0;
    spin.toValue = backwards ? @0 : @(2 * M_PI);
    spin.duration = turn;
    spin.repeatCount = HUGE_VALF;
    [band addAnimation:spin forKey:@"turn"];

    [rim.layer addSublayer:holder];
}

void SGRRingApply(UIView *host, const void *key, CGRect rect, CGFloat radius) {
    if (!host || !key) return;
    UIView *rim = objc_getAssociatedObject(host, key);
    if (!rim) {
        rim = [UIView new];
        rim.userInteractionEnabled = NO;
        rim.backgroundColor = UIColor.clearColor;
        bandIn(rim, kRingWidth * 2.3, 0.32, kRingTurn * 1.6, YES);
        bandIn(rim, kRingWidth, 1, kRingTurn, NO);
        objc_setAssociatedObject(host, key, rim, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (rim.superview != host) [host addSubview:rim];
    if (host.subviews.lastObject != rim) [host bringSubviewToFront:rim];

    CGRect bounds = (CGRect){CGPointZero, rect.size};
    if (bounds.size.width < 2 || bounds.size.height < 2) {
        rim.hidden = YES;
        return;
    }
    rim.hidden = NO;
    if (!CGRectEqualToRect(rim.bounds, bounds)) rim.bounds = bounds;
    CGPoint middle = CGPointMake(CGRectGetMidX(rect), CGRectGetMidY(rect));
    if (!CGPointEqualToPoint(rim.center, middle)) rim.center = middle;

    CGFloat side = MAX(bounds.size.width, bounds.size.height) * 2;
    CGRect canvas = CGRectMake(0, 0, side, side);
    for (CALayer *holder in rim.layer.sublayers) {
        CAShapeLayer *stroke = [holder.mask isKindOfClass:CAShapeLayer.class] ? (CAShapeLayer *)holder.mask : nil;
        if (!stroke) continue;
        CGFloat width = stroke.lineWidth;
        CGFloat corner = MAX(0, radius - width / 2);
        UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, width / 2, width / 2)
                                                      cornerRadius:corner];
        if (!CGPathEqualToPath(stroke.path, path.CGPath)) stroke.path = path.CGPath;
        if (!CGRectEqualToRect(holder.bounds, bounds)) {
            holder.bounds = bounds;
            holder.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
        }
        for (CALayer *sub in holder.sublayers) {
            if (![sub isKindOfClass:CAGradientLayer.class]) continue;
            if (!CGRectEqualToRect(sub.bounds, canvas)) {
                sub.bounds = canvas;
                sub.position = CGPointMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds));
            }
        }
    }
}
