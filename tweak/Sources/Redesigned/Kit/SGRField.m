#import "Core/SGCore.h"
#import "SGRField.h"
#import "SGRFlow.h"
#import "SGRAurora.h"
#import "SGRFluid.h"
#import "SGRBridges.h"
#import "SGRPalette.h"
#import "SGRTokens.h"

NSNotificationName const SGRFieldColorDidChangeNotification = @"spotifyglass.redesign.fieldColorDidChange";

static const CGFloat kFallbackHeight = 874;   // a window-less field sizes for an iPhone 17 Pro

// Where the color starts fading to black and where it is black, as shares of the window's height:
// the redesign is AMOLED throughout (SGRAmoled.x).
static const CGFloat kBlackFrom = 0.55, kBlackTo = 1;

static CGFloat windowHeight(UIView *view) {
    CGFloat height = view.window.bounds.size.height;
    return height > 0 ? height : kFallbackHeight;
}

// The field paints on sublayers of its own rather than on the view's layer: a repaint hook only clears
// the paint of a view's own layer, so the neutral color cannot be taken for Spotify's base surface.
static NSDictionary *noActions(void) {
    static NSDictionary *none;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNull *off = NSNull.null;
        none = @{@"bounds": off, @"position": off, @"frame": off, @"contents": off, @"backgroundColor": off, @"hidden": off, @"locations": off};
    });
    return none;
}

const NSTimeInterval SGRFieldHoldLimit = 1.0;

// The veil over a held page: black, the redesign's field before a color arrives (SGRAmoled.x), painted on a
// sublayer for the reason the field is, so the repaint hook does not take it for Spotify's base surface.
@interface SGRFieldVeil : UIView
@end

@implementation SGRFieldVeil {
    CALayer *_paint;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.accessibilityElementsHidden = YES;
    _paint = [CALayer layer];
    _paint.actions = noActions();
    _paint.backgroundColor = UIColor.blackColor.CGColor;
    [self.layer addSublayer:_paint];
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _paint.frame = self.bounds;
}

@end

@implementation SGRArtworkField {
    SGRFieldVeil *_veil;
    CFTimeInterval _heldSince;
    BOOL _shown;   // the page has been shown once, and is never held again
    CALayer *_solid;
    CAGradientLayer *_black;
    CALayer *_backdrop;
    SGRFlowLayer *_flow;
    SGRFluidLayer *_fluidLayer;
    SGRauroraLayer *_auroraLayer;
    CALayer *_cover;
    CAGradientLayer *_coverShade;
    BOOL _watching;
    NSArray<UIColor *> *_colors;   // the artwork's flow colors, for the aurora
    UIColor *_color;
    UIImage *_image;
    NSString *_identity;
    NSUInteger _generation;
    BOOL _read;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.userInteractionEnabled = NO;
    self.clipsToBounds = NO;
    self.accessibilityElementsHidden = YES;
    _color = SGRNeutralField();

    _solid = [CALayer layer];
    _solid.actions = noActions();
    _solid.backgroundColor = _color.CGColor;
    [self.layer addSublayer:_solid];

    _black = [CAGradientLayer layer];
    _black.actions = noActions();
    _black.colors = @[(id)[UIColor colorWithWhite:0 alpha:0].CGColor, (id)UIColor.blackColor.CGColor];
    [self.layer addSublayer:_black];

    _backdrop = [CALayer layer];
    _backdrop.actions = noActions();
    _backdrop.contentsGravity = kCAGravityResize;
    _backdrop.hidden = YES;
    [self.layer addSublayer:_backdrop];
    return self;
}

- (UIColor *)fieldColor {
    return _color;
}

- (CGFloat)backdropHeightNow {
    return _backdropHeight > 0 ? _backdropHeight : windowHeight(self);
}

- (void)setBleed:(UIEdgeInsets)bleed {
    _bleed = bleed;
    [self setNeedsLayout];
}

- (void)setBackdropHeight:(CGFloat)height {
    _backdropHeight = height;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    UIEdgeInsets bleed = _bleed;
    CGRect painted = CGRectMake(-bleed.left, -bleed.top, bounds.size.width + bleed.left + bleed.right, bounds.size.height + bleed.top + bleed.bottom);
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _solid.frame = painted;
    CGFloat height = windowHeight(self), total = MAX(1, painted.size.height);
    CGFloat from = height * kBlackFrom + bleed.top;
    CGFloat to = MAX(from + 1, height * kBlackTo + bleed.top);
    _black.frame = painted;
    _black.locations = @[@(MIN(1, from / total)), @(MIN(1, to / total))];
    _backdrop.frame = CGRectMake(0, 0, bounds.size.width, [self backdropHeightNow]);
    _flow.frame = CGRectMake(0, 0, bounds.size.width, [self backdropHeightNow]);
    _fluidLayer.frame = painted;
    // The screen's part of it, so the copies turn about it and the shade ends at the screen's foot.
    _fluidLayer.visibleRect = CGRectMake(bleed.left, bleed.top, bounds.size.width, height);
    _auroraLayer.frame = painted;
    _cover.frame = painted;
    _coverShade.frame = _cover.bounds;
    [CATransaction commit];
}

#pragma mark - the moving field

- (void)setFluid:(BOOL)fluid {
    if (fluid == _fluid) return;
    _fluid = fluid;
    if (fluid) {
        self.flows = NO;
        self.aurora = NO;
        self.showsCover = NO;
    }
    if (fluid && !_fluidLayer) {
        _fluidLayer = [SGRFluidLayer layer];
        [self.layer insertSublayer:_fluidLayer above:_solid];
    }
    // The fluid field is the whole picture, as the moving one is.
    _fluidLayer.hidden = !fluid || _covered;
    _black.hidden = fluid || _flows || _aurora || _showsCover;
    if (fluid) _backdrop.hidden = YES;
    if (fluid && _image) [_fluidLayer setArtwork:_image animated:NO];
    [self watch];
    [self updateMotion];
    [self setNeedsLayout];
}

- (void)setFlows:(BOOL)flows {
    if (flows == _flows) return;
    _flows = flows;
    if (flows) {
        self.fluid = NO;
        self.aurora = NO;
        self.showsCover = NO;
    }
    if (flows && !_flow) {
        _flow = [SGRFlowLayer layer];
        _flow.hidden = YES;
        [self.layer insertSublayer:_flow above:_solid];
    }
    // The moving field is the whole picture: no still backdrop over it, no fade to black under it.
    _black.hidden = flows || _fluid || _aurora || _showsCover;
    if (flows) _backdrop.hidden = YES;
    else _flow.hidden = YES;
    [self watch];
    [self updateMotion];
    [self setNeedsLayout];
}

- (void)setAurora:(BOOL)aurora {
    if (aurora == _aurora) return;
    _aurora = aurora;
    if (aurora) {
        self.flows = NO;
        self.fluid = NO;
        self.showsCover = NO;
    }
    if (aurora && !_auroraLayer) {
        _auroraLayer = [SGRauroraLayer layer];
        [self.layer insertSublayer:_auroraLayer above:_solid];
    }
    _auroraLayer.hidden = !aurora;
    _black.hidden = aurora || _flows || _fluid || _showsCover;
    if (aurora) {
        _backdrop.hidden = YES;
        if (_colors) [_auroraLayer setColors:_colors animated:NO];
        [self rereadPaletteAnimated:NO];
    }
    [self watch];
    [self updateMotion];
    [self setNeedsLayout];
}

- (void)setShowsCover:(BOOL)showsCover {
    if (showsCover == _showsCover) return;
    _showsCover = showsCover;
    if (showsCover) {
        self.flows = NO;
        self.fluid = NO;
        self.aurora = NO;
    }
    if (showsCover && !_cover) {
        _cover = [CALayer layer];
        _cover.contentsGravity = kCAGravityResizeAspectFill;
        _cover.masksToBounds = YES;
        [self.layer insertSublayer:_cover above:_solid];
        // A dark foot to the whole of it: white text sits on this, and the artwork's own bright middle must
        // not win. The field's own black gradient is off under a cover.
        _coverShade = [CAGradientLayer layer];
        _coverShade.colors = @[(id)[UIColor colorWithWhite:0 alpha:0.38].CGColor,
                               (id)[UIColor colorWithWhite:0 alpha:0.78].CGColor];
        [_cover addSublayer:_coverShade];
    }
    _cover.hidden = !showsCover;
    _black.hidden = showsCover || _flows || _fluid || _aurora;
    if (showsCover) {
        _backdrop.hidden = YES;
        if (_image) _cover.contents = (__bridge id)_image.CGImage;
        // The blurred copy is what this background is: asked for now, since the request it was read under may
        // not have rendered one.
        [self rereadPaletteAnimated:NO];
    }
    [self watch];
    [self updateMotion];
    [self setNeedsLayout];
}

// The cover drifts as the others move: a slow zoom in and back, so a still page is never quite still.
- (void)coverMoving:(BOOL)moving {
    if (!_cover) return;
    if (!moving) {
        [_cover removeAnimationForKey:@"cover.zoom"];
        return;
    }
    if ([_cover animationForKey:@"cover.zoom"]) return;
    CABasicAnimation *zoom = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    zoom.fromValue = @(1.0);
    zoom.toValue = @(1.08);
    zoom.duration = 48;
    zoom.autoreverses = YES;
    zoom.repeatCount = HUGE_VALF;
    zoom.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [_cover addAnimation:zoom forKey:@"cover.zoom"];
}

- (void)setMotionHeld:(BOOL)held {
    if (held == _motionHeld) return;
    _motionHeld = held;
    [self updateMotion];
}

- (void)setCovered:(BOOL)covered {
    if (covered == _covered) return;
    _covered = covered;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _fluidLayer.hidden = !_fluid || covered;
    [CATransaction commit];
}

- (void)watch {
    if (_watching || (!_flows && !_fluid && !_aurora && !_showsCover)) return;
    _watching = YES;
    NSNotificationCenter *center = NSNotificationCenter.defaultCenter;
    for (NSNotificationName name in @[UIApplicationDidBecomeActiveNotification, UIApplicationWillResignActiveNotification,
                                      NSProcessInfoPowerStateDidChangeNotification, UIAccessibilityReduceMotionStatusDidChangeNotification]) {
        [center addObserver:self selector:@selector(updateMotionSoon) name:name object:nil];
    }
    SGRObservePlayerTransition(self, ^(id owner) { [owner updateMotion]; }, ^(id owner) { [owner updateMotion]; });
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

// The power state is reported off the main thread.
- (void)updateMotionSoon {
    dispatch_async(dispatch_get_main_queue(), ^{ [self updateMotion]; });
}

- (void)updateMotion {
    if (!_flow && !_fluidLayer && !_auroraLayer && !_cover) return;
    // A locked phone keeps the player in its window, so being in front counts as much as being in one.
    BOOL front = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;
    BOOL may = self.window && front && !SGRPlayerIsTransitioning() && !SGRReduceMotion()
            && !NSProcessInfo.processInfo.lowPowerModeEnabled && !_motionHeld;
    _fluidLayer.moving = may && _fluid;
    _auroraLayer.moving = may && _aurora && !_auroraLayer.hidden;
    [self coverMoving:may && _showsCover];
    BOOL moving = may && _flows && !_flow.hidden;
    if (!_flow || moving == _flow.moving) return;
    _flow.moving = moving;
    static NSUInteger logged;
    if (logged++ < 6) SGLog(@"redesign kit: moving field %@", moving ? @"moves" : @"holds still");
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self updateMotion];
}

- (void)applyColor:(UIColor *)color animated:(BOOL)animated {
    if (!color || CGColorEqualToColor(color.CGColor, _color.CGColor)) return;
    CALayer *shown = _solid.presentationLayer ?: _solid;
    id from = (__bridge id)shown.backgroundColor;
    _color = color;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _solid.backgroundColor = color.CGColor;
    [CATransaction commit];
    if (animated && from) {
        CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"backgroundColor"];
        fade.fromValue = from;
        // Read back rather than the color asked for: SGRAmoled.x may have swapped it for black.
        fade.toValue = (__bridge id)_solid.backgroundColor;
        fade.duration = SGRCrossfade;
        fade.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [_solid addAnimation:fade forKey:@"backgroundColor"];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:SGRFieldColorDidChangeNotification object:self userInfo:@{@"color": color}];
}

- (void)setProvisionalColor:(UIColor *)color {
    if (_read || !color) return;
    [self applyColor:SGRFieldColorFor(color) animated:self.window != nil];
}

// What the palette is asked for, given what the field is showing now. A backdrop is rendered off the main
// thread, so it is asked for only when one of the two backgrounds that want it is on.
- (SGRPaletteRequest)paletteRequest {
    SGRPaletteRequest request = {CGSizeZero, NO, YES, _flows || _aurora, _mainColor};
    if (_flows || _fluid || _aurora || (!_showsBackdrop && !_showsCover)) return request;
    CGFloat width = self.bounds.size.width > 0 ? self.bounds.size.width : 402;
    if (_showsCover) {
        // Stretched over the whole screen and asked for at four fifths of it: enough upscaling to soften the
        // picture, little enough that the artwork still reads as itself. No live blur is composited.
        request.backdropSize = CGSizeMake(width * 0.8, windowHeight(self) * 0.8);
    } else {
        request.backdropSize = CGSizeMake(width, [self backdropHeightNow]);
    }
    return request;
}

// The palette read again for the picture already in hand: the Player page's own card changes background
// without a new track, and a backdrop that is now wanted was not rendered for the request it was read under.
- (void)rereadPaletteAnimated:(BOOL)animated {
    if (!_image) return;
    NSUInteger generation = ++_generation;
    SGRPaletteRequest request = [self paletteRequest];
    __weak SGRArtworkField *weakSelf = self;
    [SGRPalette paletteForImage:_image request:request completion:^(SGRPalette *palette) {
        SGRArtworkField *field = weakSelf;
        if (!field || !palette || generation != field->_generation) return;
        [field applyPalette:palette animated:animated && field.window != nil];
    }];
}

- (void)setArtwork:(UIImage *)image identity:(NSString *)identity animated:(BOOL)animated {
    if (!image || image == _image || (identity && [identity isEqualToString:_identity])) return;
    _image = image;
    _identity = [identity copy];
    if (_fluid) [_fluidLayer setArtwork:image animated:animated && self.window != nil];
    if (_cover) _cover.contents = (__bridge id)image.CGImage;
    [self rereadPaletteAnimated:animated];
}

#pragma mark - holding a page

- (void)holdPage:(UIView *)page {
    if (_shown || _read || !page) return;
    if (!_veil) {
        _veil = [[SGRFieldVeil alloc] initWithFrame:page.bounds];
        _heldSince = CACurrentMediaTime();
        __weak SGRArtworkField *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SGRFieldHoldLimit * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf sgr_showPage:@"the artwork took too long"];
        });
    }
    if (!CGRectEqualToRect(_veil.frame, page.bounds)) _veil.frame = page.bounds;
    // On top of everything the page holds but its pinned ⋯, which brings itself to the front on the header's
    // passes. Moved only when out of place: a move lays the page out again. The class is looked up by name so a
    // screen that has a field and no action row (the player) does not have to link SGRActionRow.m.
    static Class pinned;
    if (!pinned) pinned = NSClassFromString(@"SGRMirrorButton");
    NSArray<UIView *> *subviews = page.subviews;
    UIView *top = subviews.lastObject;
    if (pinned && [top isKindOfClass:pinned]) {
        if (subviews.count < 2 || subviews[subviews.count - 2] != _veil) [page insertSubview:_veil belowSubview:top];
    } else if (top != _veil) {
        [page addSubview:_veil];
    }
}

- (void)showPage {
    [self sgr_showPage:@"it has no artwork"];
}

- (void)sgr_showPage:(NSString *)why {
    if (_shown) return;
    _shown = YES;
    SGRFieldVeil *veil = _veil;
    _veil = nil;
    if (!veil) return;
    static NSUInteger logged;
    if (logged++ < 4) SGLog(@"redesign kit: page shown whole after %.0f ms, %@", (CACurrentMediaTime() - _heldSince) * 1000, why);
    SGRAnimate(SGRMotionFade, ^{ veil.alpha = 0; }, ^(BOOL finished) { [veil removeFromSuperview]; });
}

- (void)applyPalette:(SGRPalette *)palette animated:(BOOL)animated {
    _read = YES;
    // Under the veil the color goes in at once, and the page fades in with it.
    if (_veil) animated = NO;
    if (palette.flowColors) _colors = palette.flowColors;
    // The aurora first: its blobs are the picture, and the color under them is the field's own.
    if (_aurora && _colors) {
        [_auroraLayer setColors:_colors animated:animated && !_auroraLayer.hidden];
        _auroraLayer.hidden = NO;
        [self updateMotion];
        [self applyColor:palette.fieldColor animated:animated];
        return;
    }
    if (_flows && palette.flowColors) {
        [_flow setColors:palette.flowColors animated:animated && !_flow.hidden];
        _flow.hidden = NO;
        [self updateMotion];
        // Past the moving field's edges (the pull that dismisses the player) the color under it goes on.
        [self applyColor:_flow.baseColor animated:animated];
        return;
    }
    if (_showsCover && palette.backdrop) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _cover.contents = (__bridge id)palette.backdrop.CGImage;
        [CATransaction commit];
    }
    if (_showsBackdrop && !_flows && !_fluid && !_aurora && !_showsCover && palette.backdrop) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        if (animated) {
            CATransition *fade = [CATransition animation];
            fade.type = kCATransitionFade;
            fade.duration = SGRCrossfade;
            [_backdrop addAnimation:fade forKey:@"contents"];
        }
        _backdrop.contents = (__bridge id)palette.backdrop.CGImage;
        _backdrop.hidden = NO;
        [CATransaction commit];
    }
    [self applyColor:palette.fieldColor animated:animated];
    [self sgr_showPage:@"its artwork was read"];
}

@end
