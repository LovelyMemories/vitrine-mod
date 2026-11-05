#import "SGRestartBanner.h"
#import "Core/SGCore.h"
#import "SGPageStyle.h"

static NSInteger sg_changes;   // this launch's, and only this launch's: a restart starts at none

void SGRRestartChanged(void) {
    sg_changes++;
}

NSInteger SGRRestartChangeCount(void) {
    return sg_changes;
}

// The pill: dark glass, the count on the left, a red Restart on the right, as the newer build of this mod has it.
@interface SGRRestartBannerView : UIView
@end

@implementation SGRRestartBannerView {
    UILabel *_label;
    UIButton *_button;
    NSInteger _changes;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.92];
    self.layer.cornerRadius = 24;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.layer.borderWidth = 1 / UIScreen.mainScreen.scale;
    self.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.12].CGColor;
    self.clipsToBounds = YES;

    _label = [UILabel new];
    _label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    _label.textColor = UIColor.whiteColor;
    [self addSubview:_label];

    _button = [UIButton buttonWithType:UIButtonTypeSystem];
    // A word longer than the pill in another language is shrunk rather than cut.
    _button.titleLabel.adjustsFontSizeToFitWidth = YES;
    _button.titleLabel.minimumScaleFactor = 0.75;
    _button.backgroundColor = SGColorRGB(0xFF375F);
    _button.layer.cornerRadius = 16;
    _button.layer.cornerCurve = kCACornerCurveContinuous;
    [_button setTitle:@"Restart now" forState:UIControlStateNormal];
    [_button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    [_button addTarget:self action:@selector(restart) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_button];
    return self;
}

- (void)restart {
    SGRestartSpotify();
}

- (void)layOut {
    CGFloat width = CGRectGetWidth(self.bounds);
    CGFloat buttonWidth = MIN(128, MAX(96, CGRectGetWidth(_button.superview.bounds) * 0.34));
    _button.frame = CGRectMake(width - 16 - buttonWidth, 8, buttonWidth, 32);
    _label.frame = CGRectMake(18, 8, CGRectGetMinX(_button.frame) - 26, 32);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self layOut];
}

// The count and the words that go with it; nothing at all to say, the pill goes.
- (void)setChanges:(NSInteger)changes {
    _changes = changes;
    self.hidden = changes <= 0;
    _label.text = changes == 1 ? @"1 change needs a restart" : [NSString stringWithFormat:@"%ld changes need a restart", (long)changes];
    [self layOut];
}

@end

static SGRRestartBannerView *sg_banner;

void SGRRestartBannerAttach(UIView *host) {
    if (!host) return;
    if (!sg_banner) sg_banner = [[SGRRestartBannerView alloc] initWithFrame:CGRectZero];
    if (sg_banner.superview != host) {
        [sg_banner removeFromSuperview];
        [host addSubview:sg_banner];
    }
    // Over the page's content but above the bars it floats under: the tab bar and the now playing bar stand between
    // the banner and the screen's foot, so the pill sits on top of them rather than across the rows.
    CGRect bounds = host.bounds;
    CGFloat bottom = host.safeAreaInsets.bottom;
    CGFloat bars = 49 + 56;   // the tab bar, and the now playing bar in its row
    // Pinned by constraints rather than placed by arithmetic: the pill is where it belongs whatever the page's
    // bounds, insets or scrolling do, and it does not shift by a point when they change.
    sg_banner.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint deactivateConstraints:sg_banner.constraints];
    (void)bottom; (void)bars;
    [NSLayoutConstraint activateConstraints:@[
        [sg_banner.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:16],
        [sg_banner.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:-16],
        [sg_banner.heightAnchor constraintEqualToConstant:48],
        [sg_banner.bottomAnchor constraintEqualToAnchor:host.safeAreaLayoutGuide.bottomAnchor constant:-115],
    ]];
    sg_banner.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [host bringSubviewToFront:sg_banner];
    [sg_banner setChanges:sg_changes];
}
