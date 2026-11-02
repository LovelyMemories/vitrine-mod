// Flow's player band: the switch that picks a mode, and the mode's content under it.
//
// It sits in the room the player already gives its cover (Core/SGPlayerGeometry.h), so the title, the
// progress bar and Spotify's own controls below it are untouched. It is over the cover, so it must not
// eat the touches that belong to Spotify: -hitTest: answers nil for the band itself and passes on only
// what lands on the switch or on a mode that wants touches.
// Threading: main thread only.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Core/SGCore.h"
#import "Core/SGPlayerGeometry.h"
#import "Flow/Kit/SGFColor.h"
#import "FlowPlayer.h"
#import "FlowAura.h"
#import "FlowBside.h"
#import "FlowWaveform.h"

static char kPanelKey;
static char kWaveKey;
static const CGFloat kBarHeight = 34;
// Wide enough for three names, narrow enough to read as a switch rather than a second title.
static const CGFloat kBarMaxWidth = 260;

NSArray<NSString *> *SGFPlayerModeNames(void) {
    // Synesthesia is not offered: its bars read a tap that never reached it, and the mode is gone from the
    // player until that has an answer. The enum keeps its value so a stored mode still maps to something.
    return @[SGLocalized(@"Aura"), @"B-Side"];
}

BOOL SGFPlayerHidesVolume(void) {
    return SGFlowUI();
}

@interface SGFPlayerPanel : UIView
// How many times the band has asked to be laid out without the cover having one yet.
@property (nonatomic) NSInteger attempts;
// The last room the player gave it (CGRectNull before the first): proof that it has a place to keep.
@property (nonatomic) CGRect area;
@end

@implementation SGFPlayerPanel {
    UIView *_bar;
    UIView *_content;
    SGFAuraView *_aura;
    SGFBsideView *_bside;
    NSMutableArray<UIButton *> *_tabs;
    SGFPlayerMode _mode;
    UIImage *_artwork;
    NSInteger _restyleTick;
    CAGradientLayer *_gradient;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = SGFBlack();
    self.clipsToBounds = YES;
    // The band is painted by Flow: the cover's color at its top going to black, so nothing of Spotify's
    // shows through and the artwork Flow draws sits on Flow's own ground.
    _gradient = [CAGradientLayer layer];
    _gradient.colors = @[(id)[SGFBlack() colorWithAlphaComponent:0.92].CGColor, (id)SGFBlack().CGColor];
    [self.layer addSublayer:_gradient];
    // A new track's artwork arrives by notification. Without this the band kept the cover it first saw.
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(artworkChanged)
                                               name:SGRNowPlayingArtworkDidChangeNotification object:nil];
    // Where it was left, so a player opened again comes back to the mode last looked at.
    NSInteger stored = SGInt(SGFKeyPlayerMode, SGFPlayerModeAura);
    _mode = stored >= SGFPlayerModeAura && stored <= SGFPlayerModeBside ? (SGFPlayerMode)stored : SGFPlayerModeAura;

    _bar = [UIView new];
    _bar.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    _bar.layer.cornerRadius = kBarHeight / 2;
    _bar.layer.borderWidth = 1;
    _bar.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    _bar.layer.masksToBounds = YES;
    [self addSubview:_bar];

    _tabs = [NSMutableArray array];
    NSArray<NSString *> *names = SGFPlayerModeNames();
    for (NSUInteger i = 0; i < names.count; i++) {
        UIButton *tab = [UIButton buttonWithType:UIButtonTypeCustom];
        tab.tag = (NSInteger)i;
        tab.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        [tab setTitle:names[i] forState:UIControlStateNormal];
        [tab addTarget:self action:@selector(pick:) forControlEvents:UIControlEventTouchUpInside];
        tab.layer.cornerRadius = 13;
        [_bar addSubview:tab];
        [_tabs addObject:tab];
    }

    _content = [UIView new];
    _content.backgroundColor = UIColor.clearColor;
    _content.userInteractionEnabled = NO;
    [self addSubview:_content];
    [self paint];
    return self;
}

// Over the cover: a touch that is not on the switch is Spotify's, and goes through to it.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    return hit == self ? nil : hit;
}

- (void)pick:(UIButton *)tab {
    _mode = (SGFPlayerMode)tab.tag;
    SGSetInt(SGFKeyPlayerMode, _mode);
    [self paint];
}

- (void)paint {
    [self refreshArtwork];
    for (UIButton *tab in _tabs) {
        BOOL on = tab.tag == (NSInteger)_mode;
        tab.backgroundColor = [UIColor colorWithWhite:1 alpha:on ? 0.22 : 0];
        [tab setTitleColor:[UIColor colorWithWhite:1 alpha:on ? 1 : 0.6] forState:UIControlStateNormal];
    }
    // Only the mode on screen is mounted: they start reading the song when they enter a window (the bars
    // take the audio tap, the meters ask Sing to separate, the lines listen to the player's clock), so a
    // hidden one must be out, not merely invisible.
    UIView *wanted = [self contentForMode:_mode];
    // Out first, in second: a mode leaving gives the audio tap back, and must not take it from the one
    // that just arrived.
    for (UIView *view in [_content.subviews copy]) {
        if (view != wanted) [view removeFromSuperview];
    }
    if (wanted && wanted.superview != _content) [_content addSubview:wanted];
    wanted.frame = _content.bounds;
    [self setNeedsLayout];
}

- (UIView *)contentForMode:(SGFPlayerMode)mode {
    if (mode == SGFPlayerModeAura) {
        if (!_aura) _aura = [[SGFAuraView alloc] initWithFrame:_content.bounds];
        // A band made after the artwork was read still shows it.
        _aura.artwork = _artwork;
        return _aura;
    }
    if (mode == SGFPlayerModeBside) {
        if (!_bside) _bside = [[SGFBsideView alloc] initWithFrame:_content.bounds];
        return _bside;
    }
    return nil;
}

// The playing track's picture changed: read it again, and again a moment later, since a new track's art
// often arrives after its notification.
- (void)artworkChanged {
    _artwork = nil;
    [self refreshArtwork];
    [self setNeedsLayout];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf refreshArtwork];
    });
}

// The artwork the mod already read, and the wash it gives the band.
- (void)refreshArtwork {
    UIImage *image = SGRNowPlayingArtwork(NULL, NULL);
    if (image == _artwork) return;
    _artwork = image;
    UIColor *wash = image ? SGFWashForImage(image) : SGFBlack();
    _gradient.colors = @[(id)[wash colorWithAlphaComponent:0.92].CGColor, (id)SGFBlack().CGColor];
    _aura.artwork = image;
}

// Spotify's own progress slider, with Flow's waveform over it: the slider's track and thumb go, the bars
// take their place, and the slider itself stays where it is, under them, taking the drag and the seek.
// A view that takes no touches lets the slider beneath it have every one.
- (void)dressSlider:(UISlider *)slider {
    UIView *parent = slider.superview;
    if (!parent) return;
    SGFWaveformView *wave = objc_getAssociatedObject(slider, &kWaveKey);
    if (!wave) {
        wave = [[SGFWaveformView alloc] initWithFrame:slider.frame];
        wave.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(slider, &kWaveKey, wave, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (wave.superview != parent) [parent addSubview:wave];
    // Taller than the slider's own frame: a UISlider's bounds are mostly its thin track, and the bars need
    // room to be a waveform rather than a line.
    CGRect want = CGRectInset(slider.frame, 0, -6);
    if (!CGRectEqualToRect(wave.frame, want)) wave.frame = want;
    slider.minimumTrackTintColor = UIColor.clearColor;
    slider.maximumTrackTintColor = UIColor.clearColor;
    slider.thumbTintColor = UIColor.clearColor;
}

// Walked every twentieth pass, since the tree walked is the player's.
- (void)restyleSlidersIn:(UIView *)host {
    if (!host) return;
    // The first pass and then every twentieth: a player that is still lays out only a few times.
    NSInteger tick = ++_restyleTick;
    if (tick != 1 && tick % 20) return;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:host];
    while (queue.count) {
        UIView *view = queue.lastObject;
        [queue removeLastObject];
        if ([view isKindOfClass:UISlider.class] && ![view isDescendantOfView:self]) {
            [self dressSlider:(UISlider *)view];
        }
        [queue addObjectsFromArray:view.subviews];
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self refreshArtwork];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _gradient.frame = self.bounds;
    [CATransaction commit];
    CGFloat width = MIN(CGRectGetWidth(self.bounds) - 32, kBarMaxWidth);
    _bar.frame = CGRectMake((CGRectGetWidth(self.bounds) - width) / 2, 0, width, kBarHeight);
    CGFloat inset = 4, tabWidth = (width - inset * 2) / (CGFloat)_tabs.count;
    for (NSUInteger i = 0; i < _tabs.count; i++) {
        _tabs[i].frame = CGRectMake(inset + i * tabWidth, 4, tabWidth, kBarHeight - 8);
    }
    CGFloat top = CGRectGetMaxY(_bar.frame) + 12;
    _content.frame = CGRectMake(0, top, CGRectGetWidth(self.bounds), MAX(0, CGRectGetHeight(self.bounds) - top));
    _bside.frame = _content.bounds;
    _aura.frame = _content.bounds;
}
@end

UIView *SGFPlayerPanelIn(UIView *host) {
    if (!host) return nil;
    SGFPlayerPanel *panel = objc_getAssociatedObject(host, &kPanelKey);
    if (!panel) {
        panel = [[SGFPlayerPanel alloc] initWithFrame:CGRectZero];
        objc_setAssociatedObject(host, &kPanelKey, panel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (panel.superview != host) [host addSubview:panel];
    return panel;
}

void SGFPlayerPanelLayout(UIView *host) {
    SGFPlayerPanel *panel = host ? objc_getAssociatedObject(host, &kPanelKey) : nil;
    if (!panel) return;
    CGRect area = SGRPlayerArtworkAreaIn(host);
    // Nothing to draw into: no cover has laid out yet, or the player is closing.
    if (CGRectIsNull(area) || area.size.height < 80) {
        // Once it has a place, a pass that cannot measure keeps the last one. Spotify gives the band no
        // frame for a pass here and there (a track change, the player settling), and the panel -- the switch
        // included -- must not blink out with it.
        if (!CGRectIsNull(panel.area)) {
            panel.hidden = NO;
            return;
        }
        panel.hidden = YES;
        // The player's first pass can come before the cover has a frame. Ask again a few times rather
        // than wait for a layout that a still player may never get; after that, its own pass will do.
        if (panel.attempts < 10) {
            panel.attempts++;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SGFPlayerPanelLayout(host);
            });
        }
        return;
    }
    panel.attempts = 0;
    panel.area = area;
    panel.hidden = NO;
    panel.frame = area;
    static BOOL logged;
    if (!logged) {
        logged = YES;
        SGLog(@"flow: the band in %@, mode %ld", NSStringFromCGRect(area), (long)SGInt(SGFKeyPlayerMode, 0));
    }
    [panel setNeedsLayout];
    [panel restyleSlidersIn:host];
}
