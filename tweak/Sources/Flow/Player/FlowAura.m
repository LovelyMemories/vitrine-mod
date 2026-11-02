// Flow's Aura mode: the cover, smaller, and the line being sung under it -- the composition of the Flow
// mock, drawn by Flow itself.
//
// The band the player gives its artwork is Flow's here: the band's own background is the cover's wash, the
// smaller cover is drawn from the artwork the mod already reads (Core/SGPlayerGeometry.h), and the lines
// come from Shared/Lyrics' own (SGKaraokeLeadLine), the same ones the lock screen shows. Spotify's own
// cover and its lyric preview are simply behind that background, which is why nothing can collide with
// them.
// Threading: main thread only.
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Core/SGPlayerGeometry.h"
#import "Shared/Lyrics/Lyrics.h"
#import "FlowAura.h"

static const CGFloat kCoverSide = 240;

@implementation SGFAuraView {
    UIImageView *_cover;
    UILabel *_before, *_now, *_after;
    NSTimer *_timer;
    BOOL _fitsBefore, _fitsAfter;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;

    _cover = [[UIImageView alloc] initWithFrame:CGRectZero];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.clipsToBounds = YES;
    _cover.layer.cornerRadius = 14;
    _cover.layer.cornerCurve = kCACornerCurveContinuous;
    _cover.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
    [self addSubview:_cover];

    _before = [self addLine:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[UIColor colorWithWhite:1 alpha:0.45]];
    _after = [self addLine:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[UIColor colorWithWhite:1 alpha:0.45]];
    _now = [self addLine:[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold] color:UIColor.whiteColor];
    return self;
}

- (void)dealloc {
    [self end];
}

- (void)setArtwork:(UIImage *)artwork {
    if (artwork == _artwork) return;
    _artwork = artwork;
    _cover.image = artwork;
}

- (UILabel *)addLine:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.hidden = YES;
    [self addSubview:label];
    return label;
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self begin];
    else [self end];
}

- (void)begin {
    if (_timer) return;
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    [self tick];
}

- (void)end {
    [_timer invalidate];
    _timer = nil;
}

- (void)tick {
    NSString *track = SGKaraokePlayingTrack();
    NSInteger position = SGKaraokePositionMs();
    NSArray<SGKaraokeLine *> *lines = track && position >= 0 ? SGKaraokeLinesForTrack(track) : nil;
    // The Lyrics page's delay is the same one every reader of these lines applies.
    NSInteger ms = position - SGKaraokeDelayMs();
    NSInteger lead = lines.count ? SGKaraokeLeadLine(lines, ms) : -1;
    if (lead < 0) {
        _before.hidden = _now.hidden = _after.hidden = YES;
        [self setNeedsLayout];
        return;
    }
    _now.text = SGKaraokeLineText(lines[(NSUInteger)lead]);
    _before.text = lead > 0 ? SGKaraokeLineText(lines[(NSUInteger)lead - 1]) : nil;
    _after.text = lead + 1 < (NSInteger)lines.count ? SGKaraokeLineText(lines[(NSUInteger)lead + 1]) : nil;
    _now.hidden = NO;
    _before.hidden = !_fitsBefore || _before.text.length == 0;
    _after.hidden = !_fitsAfter || _after.text.length == 0;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    const CGFloat nowHeight = 44, lineHeight = 32, gap = 6, foot = 4;

    // The cover takes what is left once the lines have their room, and never more than the mock's 240pt.
    CGFloat linesRoom = nowHeight + lineHeight + gap + foot;
    CGFloat side = MIN(kCoverSide, MIN(width - 40, height - linesRoom - 14));
    _cover.hidden = side < 96;
    if (_cover.hidden) side = 0;
    _cover.frame = CGRectMake((width - side) / 2, 0, side, side);

    CGFloat top = (side > 0 ? side + 14 : 0) + foot;
    CGFloat room = height - top;
    _fitsBefore = room >= nowHeight + lineHeight + gap;
    _fitsAfter = room >= nowHeight + 8;
    if (_fitsBefore) top += lineHeight + gap;

    _now.frame = CGRectMake(8, top, width - 16, nowHeight);
    top += nowHeight;
    if (_fitsAfter) {
        _after.frame = CGRectMake(8, top + 2, width - 16, lineHeight);
    }
    if (_fitsBefore) {
        _before.frame = CGRectMake(8, CGRectGetMinY(_now.frame) - lineHeight - gap, width - 16, lineHeight);
    }
}

@end
