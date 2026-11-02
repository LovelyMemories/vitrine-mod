// Flow's B-Side mode: the song's two halves, mixed and metered.
//
// Two rows, the voice and the rest, each with a slider and a meter. The meters are Sing's own separation
// (Shared/Sing) through SGSingReadLevels; nothing is read while Sing is off, since reading is what makes
// the model separate.
//
// The sliders are real gains: the voice's is Sing's own level (SGSetSingLevel), the rest's is the engine's
// second gain (SGSetSingRest), which scales the rest beside it. Both go back where they were when the mode
// lets go. When Sing is off the card says so and offers the switch that turns it on, rather than leaving
// the reader to find a setting three pages away.
// Threading: main thread only.
#import <UIKit/UIKit.h>
#import <math.h>
#import "Core/SGCore.h"
#import "Flow/Kit/SGFColor.h"
#import "Shared/Sing/Sing.h"
#import "FlowBside.h"

// Two rows, their meters and the line (or the button) under them.
static const CGFloat kCardHeight = 152;

// A small round thumb of Flow's own, so a slider reads as a mixer and not as a system control.
static UIImage *dot(CGFloat diameter, UIColor *color) {
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(diameter, diameter)];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [color setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, diameter, diameter)] fill];
    }];
}

@implementation SGFBsideView {
    UIVisualEffectView *_card;
    UILabel *_voice, *_rest, *_status;
    UISlider *_voiceSlider, *_restSlider;
    UIButton *_sing;
    UIView *_voiceTrack, *_restTrack, *_voiceFill, *_restFill;
    NSTimer *_timer;
    CGFloat _voiceShare, _restShare;
    float _voiceWas, _restWas;
    BOOL _captured;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    _card = [[UIVisualEffectView alloc] initWithEffect:SGGlassEffect()];
    _card.layer.cornerRadius = 22;
    _card.layer.masksToBounds = YES;
    _card.layer.borderWidth = 1;
    _card.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.10].CGColor;
    [self addSubview:_card];

    UIFont *small = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    UIColor *dim = [UIColor colorWithWhite:1 alpha:0.55];
    _voice = [self addLabel:@"Voice" font:small color:dim];
    _rest = [self addLabel:@"Rest" font:small color:dim];
    _status = [self addLabel:@"" font:[UIFont systemFontOfSize:11 weight:UIFontWeightRegular]
                       color:[UIColor colorWithWhite:1 alpha:0.45]];
    _status.numberOfLines = 2;

    _voiceSlider = [self addSlider];
    _restSlider = [self addSlider];
    [_voiceSlider addTarget:self action:@selector(voiceChanged) forControlEvents:UIControlEventValueChanged];
    [_restSlider addTarget:self action:@selector(restChanged) forControlEvents:UIControlEventValueChanged];

    _sing = [UIButton buttonWithType:UIButtonTypeCustom];
    [_sing setTitle:SGLocalized(@"Turn on Sing") forState:UIControlStateNormal];
    [_sing setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    _sing.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    _sing.backgroundColor = SGFAccent();
    _sing.layer.cornerRadius = 10;
    [_sing addTarget:self action:@selector(singTapped) forControlEvents:UIControlEventTouchUpInside];
    [_card.contentView addSubview:_sing];

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
    label.text = SGLocalized(text);
    label.font = font;
    label.textColor = color;
    [_card.contentView addSubview:label];
    return label;
}

- (UISlider *)addSlider {
    UISlider *slider = [UISlider new];
    slider.minimumValue = 0;
    slider.maximumValue = 1;
    slider.minimumTrackTintColor = SGFAccent();
    slider.maximumTrackTintColor = [UIColor colorWithWhite:1 alpha:0.14];
    UIImage *thumb = dot(14, UIColor.whiteColor);
    [slider setThumbImage:thumb forState:UIControlStateNormal];
    [slider setThumbImage:thumb forState:UIControlStateHighlighted];
    [_card.contentView addSubview:slider];
    return slider;
}

- (UIView *)addTrack {
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.10];
    view.layer.cornerRadius = 2;
    view.layer.masksToBounds = YES;
    [_card.contentView addSubview:view];
    return view;
}

- (UIView *)addFill {
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor colorWithWhite:1 alpha:0.55];
    view.layer.cornerRadius = 2;
    return view;
}

- (void)voiceChanged {
    SGSetSingLevel(_voiceSlider.value);
}

- (void)restChanged {
    SGSetSingRest(_restSlider.value);
}

- (void)singTapped {
    SGSetSingOn(YES);
    [self tick];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self begin];
    else [self end];
}

- (void)begin {
    if (_timer) return;
    // What the song was mixed at before B-Side touched it, put back when it lets go.
    _voiceWas = SGSingLevel();
    _restWas = SGSingRest();
    _captured = YES;
    _voiceSlider.value = fminf(1, _voiceWas);
    _restSlider.value = _restWas;
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.25 repeats:YES block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    [self tick];
}

- (void)end {
    [_timer invalidate];
    _timer = nil;
    if (!_captured) return;
    _captured = NO;
    SGSetSingLevel(_voiceWas);
    SGSetSingRest(_restWas);
}

// The newest tenths, averaged: one tenth moves too much to read as a level.
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

    // Off: the switch that turns it on stands where the line would be.
    _sing.hidden = on;
    if (on) {
        NSString *status = heard ? @"" : (SGSingStatusText() ?: @"The separation model is not loaded.");
        status = status.length ? SGLocalized(status) : @"";
        if (![_status.text isEqualToString:status]) _status.text = status;
    } else {
        _status.text = SGLocalized(@"Sing is off. Turn it on and the model's two halves show here.");
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    CGFloat cardHeight = MIN(kCardHeight, height);
    // Inset from the screen's edges, as the player's own title and controls are.
    _card.frame = CGRectMake(8, height - cardHeight, MAX(0, width - 16), cardHeight);

    CGFloat pad = 18, labelWidth = 72, gap = 8, sliderHeight = 30;
    CGFloat inner = MAX(0, CGRectGetWidth(_card.bounds) - pad * 2);
    CGFloat sliderWidth = MAX(0, inner - labelWidth - gap);

    _voice.frame = CGRectMake(pad, 14, labelWidth, 14);
    _voiceSlider.frame = CGRectMake(pad + labelWidth + gap, 6, sliderWidth, sliderHeight);
    _voiceTrack.frame = CGRectMake(pad, 42, inner, 3);

    _rest.frame = CGRectMake(pad, 56, labelWidth, 14);
    _restSlider.frame = CGRectMake(pad + labelWidth + gap, 48, sliderWidth, sliderHeight);
    _restTrack.frame = CGRectMake(pad, 84, inner, 3);

    _status.frame = CGRectMake(pad, 96, inner, 32);
    CGSize button = CGSizeMake(MIN(inner, 176), 34);
    _sing.frame = CGRectMake(pad, 96 + (32 - button.height) / 2, button.width, button.height);

    // A meter always shows a sliver, so a silent half reads as a meter at rest rather than as a missing row.
    _voiceFill.frame = CGRectMake(0, 0, inner * MAX(0.02, _voiceShare), 3);
    _restFill.frame = CGRectMake(0, 0, inner * MAX(0.02, _restShare), 3);
}

@end
