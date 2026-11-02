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
#import "FlowSynesthesia.h"

static char kPanelKey;
static const CGFloat kBarHeight = 34;
// Wide enough for three names, narrow enough to read as a switch rather than a second title.
static const CGFloat kBarMaxWidth = 260;

NSArray<NSString *> *SGFPlayerModeNames(void) {
    return @[@"Aura", @"B-Side", @"Synesthesia"];
}

@interface SGFPlayerPanel : UIView
// How many times the band has asked to be laid out without the cover having one yet.
@property (nonatomic) NSInteger attempts;
// Where Spotify draws the cover, in the panel's coordinates (CGRectNull when it has none): the room Aura
// may use is only what is under it.
@property (nonatomic) CGRect coverFrame;
@end

@implementation SGFPlayerPanel {
    UIView *_bar;
    UIView *_content;
    SGFAuraView *_aura;
    SGFSynesthesiaView *_synesthesia;
    SGFBsideView *_bside;
    NSMutableArray<UIButton *> *_tabs;
    SGFPlayerMode _mode;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    // Where it was left, so a player opened again comes back to the mode last looked at.
    NSInteger stored = SGInt(SGFKeyPlayerMode, SGFPlayerModeAura);
    _mode = stored >= SGFPlayerModeAura && stored <= SGFPlayerModeSynesthesia ? (SGFPlayerMode)stored : SGFPlayerModeAura;

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
        return _aura;
    }
    if (mode == SGFPlayerModeSynesthesia) {
        if (!_synesthesia) _synesthesia = [[SGFSynesthesiaView alloc] initWithFrame:_content.bounds];
        return _synesthesia;
    }
    if (mode == SGFPlayerModeBside) {
        if (!_bside) _bside = [[SGFBsideView alloc] initWithFrame:_content.bounds];
        return _bside;
    }
    return nil;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = MIN(CGRectGetWidth(self.bounds) - 32, kBarMaxWidth);
    _bar.frame = CGRectMake((CGRectGetWidth(self.bounds) - width) / 2, 0, width, kBarHeight);
    CGFloat inset = 4, tabWidth = (width - inset * 2) / (CGFloat)_tabs.count;
    for (NSUInteger i = 0; i < _tabs.count; i++) {
        _tabs[i].frame = CGRectMake(inset + i * tabWidth, 4, tabWidth, kBarHeight - 8);
    }
    CGFloat top = CGRectGetMaxY(_bar.frame) + 12;
    _content.frame = CGRectMake(0, top, CGRectGetWidth(self.bounds), MAX(0, CGRectGetHeight(self.bounds) - top));
    _synesthesia.frame = _content.bounds;
    _bside.frame = _content.bounds;
    _aura.frame = _content.bounds;
    // Aura may draw only under the cover, so it is told where the cover is, in its own coordinates.
    if (_aura) _aura.coverFrame = CGRectIsNull(self.coverFrame) ? CGRectNull : [_aura convertRect:self.coverFrame fromView:self];
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
    panel.hidden = NO;
    panel.frame = area;
    // Aura needs the cover's own frame, which is not the band's: the cover sits inside it.
    CGRect cover = SGRPlayerCoverFrameIn(host);
    panel.coverFrame = CGRectIsNull(cover) ? CGRectNull : [panel convertRect:cover fromView:host];
    [panel setNeedsLayout];
}
