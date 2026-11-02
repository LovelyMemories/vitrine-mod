// Flow's waveform: the song's own shape, built as it plays.
//
// The player's progress line is Spotify's slider, and it stays Spotify's: Flow lays this view over it and
// makes the slider's own track transparent, so the drag, the seeking and the accessibility are still its
// own and only the picture changes.
//
// The bars are not decoration and not a guess. The spectrum the player already taps (Core/SGSpectrum.h) is
// turned into a loudness ten times a second and kept in the bar the song is passing at that moment, so the
// part already heard fills with the shape it really had; the rest stays a flat line until it is reached.
// A seek invents nothing: what is behind the jump keeps the shape it got.
// Threading: main thread only, but for the render thread's hand-off inside the spectrum.
#import <UIKit/UIKit.h>
#import <math.h>
#import "Core/SGCore.h"
#import "Core/SGSpectrum.h"
#import "Shared/Player/PlayerState.h"
#import "Flow/Kit/SGFColor.h"
#import "FlowWaveform.h"

enum { kSGFWaveBars = 64 };

@implementation SGFWaveformView {
    float _levels[kSGFWaveBars];
    CGFloat _share;
    CGFloat _seconds;
    NSTimer *_timer;
    BOOL _fed;
    BOOL _analyzed;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.opaque = NO;
    self.userInteractionEnabled = NO;
    for (int i = 0; i < kSGFWaveBars; i++) _levels[i] = 0.05f;
    return self;
}

- (void)dealloc {
    [self leave];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self enter];
    else [self leave];
}

- (void)enter {
    SGRSpectrumPrepare();
    SGAudioSetOutputReader(SGRSpectrumFeed);
    _fed = YES;
    if (_timer) return;
    __weak typeof(self) weakSelf = self;
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    [self tick];
}

- (void)leave {
    if (_fed) {
        SGAudioSetOutputReader(NULL);
        _fed = NO;
    }
    [_timer invalidate];
    _timer = nil;
}

- (void)setShare:(CGFloat)share seconds:(CGFloat)seconds {
    _seconds = seconds;
    share = fmax(0, fmin(1, share));
    if (fabs(share - _share) < 0.002) return;
    _share = share;
    [self setNeedsDisplay];
}

- (void)tick {
    // The tap is one for the app, and the redesign's Visualizer and Flow's Synesthesia take it and give it
    // back as their views move. Taken again here, so no one else's leaving silences the bar.
    SGAudioSetOutputReader(SGRSpectrumFeed);
    _fed = YES;
    SPTPlayerState *state = SGPlayerState();
    if (!state) return;
    double position = state.isPaused ? state.positionAsOfTimestamp : state.position;
    double duration = [state respondsToSelector:@selector(duration)] ? state.duration : 0;
    if (duration > 0) {
        [self setShare:(CGFloat)(position / duration) seconds:(CGFloat)duration];
        NSInteger at = (NSInteger)(_share * kSGFWaveBars);
        if (at >= 0 && at < kSGFWaveBars) {
            float bands[SGRSpectrumBands];
            uint64_t generation = SGRSpectrumRead(bands);
            if (generation > 0) _analyzed = YES;
            float peak = SGRSpectrumFloor;
            for (int i = 0; i < SGRSpectrumBands; i++) if (bands[i] > peak) peak = bands[i];
            float share = (peak - SGRSpectrumFloor) / -SGRSpectrumFloor;
            share = powf(fmaxf(0, fminf(1, share)), 1.4f);
            // A bar keeps the loudest it has been heard: the song's shape, not one moment of it.
            if (share > _levels[at]) {
                _levels[at] = share;
                [self setNeedsDisplay];
            }
        }
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    if (width < 1 || height < 1) return;
    // No analysis has ever arrived: this build cannot reach Spotify's output at all (the log's
    // "AudioOutputUnitStart" line), so there is no shape to draw. A clean two-tone bar says where the song
    // is without pretending to know how it sounds.
    if (!_analyzed) {
        CGFloat line = 6;
        CGRect track = CGRectMake(0, (height - line) / 2, width, line);
        [[UIColor colorWithWhite:1 alpha:0.16] setFill];
        [[UIBezierPath bezierPathWithRoundedRect:track cornerRadius:line / 2] fill];
        CGFloat played = width * _share;
        if (played > 1) {
            [SGFAccent() setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, track.origin.y, played, line) cornerRadius:line / 2] fill];
        }
        return;
    }
    CGFloat gap = 2;
    CGFloat cell = (width - gap * (kSGFWaveBars - 1)) / kSGFWaveBars;
    if (cell < 1) {
        cell = width / kSGFWaveBars;
        gap = 0;
    }
    NSInteger playedTo = (NSInteger)(_share * kSGFWaveBars);
    UIColor *played = SGFAccent();
    UIColor *ahead = [UIColor colorWithWhite:1 alpha:0.22];
    for (int i = 0; i < kSGFWaveBars; i++) {
        CGFloat share = 0.12 + 0.88 * _levels[i];
        CGFloat barHeight = MAX(2, share * height);
        CGRect bar = CGRectMake(i * (cell + gap), (height - barHeight) / 2, cell, barHeight);
        [(i < playedTo ? played : ahead) setFill];
        [[UIBezierPath bezierPathWithRoundedRect:bar cornerRadius:MIN(cell / 2, 2)] fill];
    }
}

@end
