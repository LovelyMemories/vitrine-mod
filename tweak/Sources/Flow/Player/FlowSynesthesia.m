// Flow's Synesthesia mode: the song drawn as a row of bars, in Flow's color, read from the spectrum the
// player already taps (Core/SGSpectrum.h, fed here through SGAudioSetOutputReader).
//
// The bars are the bands, not a timer: a silent passage reads as a flat row at the floor, and a kick
// stands the low bars up. Each reading eases into the last, so the row moves with the song rather than
// with its own idea of it.
//
// Motion: a display link at 30 Hz, not the player's 120 (AGENTS.md: a 60 Hz link drags the player's
// transitions down with it), stopped the moment the view leaves the window.
// Threading: main thread only, but for the render thread's hand-off inside the spectrum.
#import <UIKit/UIKit.h>
#import <math.h>
#import "Core/SGCore.h"
#import "Core/SGSpectrum.h"
#import "Shared/AudioEffects/AudioEffects.h"
#import "Flow/Kit/SGFColor.h"
#import "FlowSynesthesia.h"

@implementation SGFSynesthesiaView {
    CADisplayLink *_link;
    float _levels[SGRSpectrumBands];
    float _shown[SGRSpectrumBands];
    uint64_t _generation;
    CGSize _laidOut;
    BOOL _fed;
    BOOL _diagnosed;
    int _quietTicks;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.opaque = NO;
    for (int band = 0; band < SGRSpectrumBands; band++) _levels[band] = SGRSpectrumFloor;
    return self;
}

- (void)dealloc {
    [self leave];
}

// The tap is one for the whole app (SGAudioSetOutputReader): taken while this mode is on screen, and
// given back only by the view that took it, so a second player never clears another's reader.
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window) [self enter];
    else [self leave];
}

- (void)enter {
    SGRSpectrumPrepare();
    SGAudioSetOutputReader(SGRSpectrumFeed);
    _fed = YES;
    if (_link) return;
    _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick)];
    _link.preferredFrameRateRange = CAFrameRateRangeMake(24, 30, 30);
    [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
}

- (void)leave {
    // Given back before anything else can ask for it: a view that leaves must not hold the tap.
    if (_fed) {
        SGAudioSetOutputReader(NULL);
        _fed = NO;
    }
    [_link invalidate];
    _link = nil;
    _generation = 0;
    for (int band = 0; band < SGRSpectrumBands; band++) _shown[band] = 0;
}

- (void)tick {
    // The audio tap is one for the whole app, and the redesign's own Visualizer takes and gives it back as
    // its view moves. Taking it again on every tick costs an atomic store and makes the bars independent of
    // whoever else asked for it last.
    SGAudioSetOutputReader(SGRSpectrumFeed);
    _fed = YES;
    uint64_t generation = SGRSpectrumRead(_levels);
    if (generation == _generation) {
        // Nothing new: paused, or the tap never ran. Said once, so a device log tells which.
        if (!_diagnosed && ++_quietTicks > 60) {
            _diagnosed = YES;
            SGLog(@"flow: the spectrum has had nothing for 2 s (tick %d)", _quietTicks);
        }
        return;
    }
    _quietTicks = 0;
    if (!_diagnosed) {
        _diagnosed = YES;
        SGLog(@"flow: the spectrum reads %llu analyses", (unsigned long long)generation);
    }
    _generation = generation;
    [self setNeedsDisplay];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (CGSizeEqualToSize(_laidOut, self.bounds.size)) return;
    _laidOut = self.bounds.size;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    CGFloat width = CGRectGetWidth(self.bounds), height = CGRectGetHeight(self.bounds);
    if (width < 1 || height < 1) return;
    // The bars stand on the artwork's lower edge: a gradient into black is what makes the row read as part
    // of the player rather than as marks on the cover. Drawn here rather than as a sublayer, which would
    // lie over the bars: a layer's contents is under everything the layer's sublayers draw.
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {0, 0, 0, 0, 0, 0, 0, 0.8};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(space, components, NULL, 2);
    if (gradient) {
        CGContextDrawLinearGradient(context, gradient, CGPointMake(0, height - 110), CGPointMake(0, height), 0);
        CGGradientRelease(gradient);
    }
    CGColorSpaceRelease(space);
    const CGFloat gap = 3;
    CGFloat cell = (width - gap * (SGRSpectrumBands - 1)) / SGRSpectrumBands;
    if (cell < 1) cell = 1;
    UIColor *light = SGFAccent();
    for (int band = 0; band < SGRSpectrumBands; band++) {
        // dB to a share of the height: the floor is nothing, a full scale sine the whole of it.
        float share = (_levels[band] - SGRSpectrumFloor) / -SGRSpectrumFloor;
        share = fmaxf(0, fminf(1, share));
        share = powf(share, 1.6f);
        CGFloat target = share * height;
        // A new reading eases into the last, so the row does not flicker with the analysis.
        CGFloat shown = _shown[band] + (target - _shown[band]) * 0.45;
        _shown[band] = (float)shown;
        CGFloat barHeight = MAX(2, shown);
        CGRect bar = CGRectMake(band * (cell + gap), height - barHeight, cell, barHeight);
        [[light colorWithAlphaComponent:0.25 + 0.75 * share] setFill];
        [[UIBezierPath bezierPathWithRoundedRect:bar cornerRadius:MIN(cell / 2, 4)] fill];
    }
}

@end
