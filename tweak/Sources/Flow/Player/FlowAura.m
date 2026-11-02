// Flow's Aura mode: the line being sung, and the two around it, in whatever room the cover leaves.
//
// The band the player gives its artwork is mostly cover, and Spotify draws its own lyric preview under
// it. So Aura never draws over the cover: it takes the cover's frame (Core/SGPlayerGeometry.h) and puts
// its three lines in the room below it, and where there is none -- the cover filling the band, as it
// usually does -- it draws nothing at all rather than lie on top of Spotify's preview.
//
// The lines are Shared/Lyrics' own (SGKaraokeLinesForTrack, SGKaraokeLeadLine), the same ones the lock
// screen shows, so Aura adds a reader rather than a second lyrics engine.
// Threading: main thread only.
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"
#import "Shared/Lyrics/Lyrics.h"
#import "Flow/Kit/SGFColor.h"
#import "FlowAura.h"

@implementation SGFAuraView {
    UILabel *_before, *_now, *_after;
    NSTimer *_timer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    _before = [self addLine:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[UIColor colorWithWhite:1 alpha:0.42]];
    _after = [self addLine:[UIFont systemFontOfSize:12 weight:UIFontWeightMedium] color:[UIColor colorWithWhite:1 alpha:0.42]];
    _now = [self addLine:[UIFont systemFontOfSize:17 weight:UIFontWeightSemibold] color:UIColor.whiteColor];
    return self;
}

- (void)dealloc {
    [self end];
}

- (UILabel *)addLine:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.font = font;
    label.textColor = color;
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 1;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.7;
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

- (void)setCoverFrame:(CGRect)coverFrame {
    if (CGRectEqualToRect(_coverFrame, coverFrame)) return;
    _coverFrame = coverFrame;
    [self setNeedsLayout];
}

// The room under the cover, in this view's own coordinates: nothing above the cover, nothing off the end.
// With no cover frame known there is no room either: drawing at the top of the band would be drawing over
// the cover, which is the one thing Aura does not do.
- (CGRect)room {
    if (CGRectIsNull(_coverFrame)) return CGRectNull;
    CGFloat top = CGRectGetMaxY(_coverFrame);
    if (top < 0) top = 0;
    CGFloat height = CGRectGetHeight(self.bounds) - top;
    if (height < 44) return CGRectNull;
    return CGRectMake(0, top, CGRectGetWidth(self.bounds), height);
}

- (void)tick {
    NSString *track = SGKaraokePlayingTrack();
    NSInteger position = SGKaraokePositionMs();
    NSArray<SGKaraokeLine *> *lines = track && position >= 0 ? SGKaraokeLinesForTrack(track) : nil;
    // The Lyrics page's delay is the same one every reader of these lines applies.
    NSInteger ms = position - SGKaraokeDelayMs();
    NSInteger lead = lines.count && !CGRectIsNull([self room]) ? SGKaraokeLeadLine(lines, ms) : -1;
    if (lead < 0) {
        _before.hidden = _now.hidden = _after.hidden = YES;
        return;
    }
    _now.text = SGKaraokeLineText(lines[(NSUInteger)lead]);
    _before.text = lead > 0 ? SGKaraokeLineText(lines[(NSUInteger)lead - 1]) : nil;
    _after.text = lead + 1 < (NSInteger)lines.count ? SGKaraokeLineText(lines[(NSUInteger)lead + 1]) : nil;
    _now.hidden = NO;
    _before.hidden = _before.text.length == 0;
    _after.hidden = _after.text.length == 0;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect room = [self room];
    if (CGRectIsNull(room)) {
        _before.hidden = _now.hidden = _after.hidden = YES;
        return;
    }
    CGFloat lineHeight = 18, gap = 6, width = CGRectGetWidth(self.bounds);
    _now.frame = CGRectMake(0, CGRectGetMinY(room), width, lineHeight + 4);
    _before.frame = CGRectMake(0, CGRectGetMinY(_now.frame) - lineHeight - gap, width, lineHeight);
    _after.frame = CGRectMake(0, CGRectGetMaxY(_now.frame) + gap, width, lineHeight);
}

@end
