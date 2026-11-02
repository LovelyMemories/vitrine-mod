// Flow's B-Side mode: what the separation model hears, as it hears it.
//
// Two meters, the voice and the rest of the song, from Sing's own separation (Shared/Sing): the RMS of
// each, per tenth of a second, read through SGSingReadLevels. Reading them is also what keeps the model
// separating -- with the vocals as sung and Spatial voice off, Sing rests unless a page asks -- so this
// mode listens to the model rather than to a second, made-up analyser.
//
// Nothing here claims four stems: Sing's model gives the voice and everything else, and that is what the
// two meters are. With no model, or with the iPhone too hot for it, the meters stay down and the line
// under them says what Sing is doing instead of pretending to hear something.
// Threading: main thread only.
#import <UIKit/UIKit.h>
#import <math.h>
#import "Core/SGCore.h"
#import "Flow/Kit/SGFColor.h"
#import "Shared/Sing/Sing.h"
#import "FlowBside.h"

@implementation SGFBsideView {
    UILabel *_voice, *_rest, *_status;
    UIView *_voiceTrack, *_voiceFill, *_restTrack, *_restFill;
    NSTimer *_timer;
    CGFloat _voiceShare, _restShare;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    UIFont *small = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    UIColor *dim = [UIColor colorWithWhite:1 alpha:0.55];
    _voice = [self addLabel:@"Voice" font:small color:dim];
    _rest = [self addLabel:@"Rest" font:small color:dim];
    _status = [self addLabel:@"" font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
                       color:[UIColor colorWithWhite:1 alpha:0.45]];
    _status.numberOfLines = 2;
    _voiceTrack = [self addTrack];
    _restTrack = [self addTrack];
    _voiceFill = [self addFill];
    _restFill = [self addFill];
    [_voiceTrack addSubview:_voiceFill];
    [_restTrack addSubview:_restFill];
    return self;
}

- (void)dealloc {
    [self end];
}

- (UILabel *)addLabel:(NSString *)text font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = font;
    label.textColor = color;
    [self addSubview:label];
    return label;
}

- (UIView *)addTrack {
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    view.layer.cornerRadius = 3;
    view.layer.masksToBounds = YES;
    [self addSubview:view];
    return view;
}

- (UIView *)addFill {
    UIView *view = [UIView new];
    view.backgroundColor = SGFAccent();
    view.layer.cornerRadius = 3;
    return view;
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

// The newest tenths, averaged: one tenth moves too much to read as a level. Nothing is read at all while
// Sing is off: reading is what makes it separate, and a meter is not worth running the model for.
- (void)tick {
    enum { kTenths = 12, kAverage = 3 };
    BOOL on = SGSingOn();
    float vocals[kTenths], rest[kTenths];
    BOOL heard = on && SGSingReadLevels(vocals, rest, kTenths);
    float voice = 0, other = 0;
    if (heard) {
        for (int i = kTenths - kAverage; i < kTenths; i++) {
            voice += vocals[i];
            other += rest[i];
        }
        voice /= kAverage;
        other /= kAverage;
    }
    // RMS of a song runs low; the ear does not.
    _voiceShare = heard ? powf(MIN(1, voice * 3.5f), 0.7f) : 0;
    _restShare = heard ? powf(MIN(1, other * 3.5f), 0.7f) : 0;
    NSString *status;
    if (!on) status = @"Sing is off. Turn it on and the model's two halves show here.";
    else if (heard) status = @"The model's own two halves. Turning them apart comes next.";
    else status = SGSingStatusText() ?: @"The separation model is not loaded.";
    if (![_status.text isEqualToString:status]) _status.text = status;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), labelWidth = 52, gap = 8;
    CGFloat trackWidth = MAX(0, width - labelWidth - gap);
    _voice.frame = CGRectMake(0, 0, labelWidth, 14);
    _voiceTrack.frame = CGRectMake(labelWidth + gap, 3, trackWidth, 8);
    _rest.frame = CGRectMake(0, 20, labelWidth, 14);
    _restTrack.frame = CGRectMake(labelWidth + gap, 23, trackWidth, 8);
    _status.frame = CGRectMake(0, 44, width, 30);
    // A meter always shows a sliver, so a silent half reads as a meter at rest rather than as a missing row.
    _voiceFill.frame = CGRectMake(0, 0, trackWidth * MAX(0.02, _voiceShare), 8);
    _restFill.frame = CGRectMake(0, 0, trackWidth * MAX(0.02, _restShare), 8);
}

@end
