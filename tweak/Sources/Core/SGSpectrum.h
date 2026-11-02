// The song's spectrum, cut into SGRSpectrumBands bands spaced evenly in pitch from 50 Hz to 14 kHz, each
// band's level in dB, 0 dB being a full scale sine in it.
//
// Declared here, in Core, though only Redesigned/Player/SGRSpectrum.m defines it: two looks draw the same
// player (Redesigned/Player/PlayerVisualiser.m and Flow/Player/FlowSynesthesia.m), and neither may import
// the other. AGENTS.md's rule for that is a function declared low and defined high, which this is; the
// names keep the implementation's prefix because that is the file that owns them.
//
// Every 1024 samples the last 4096, through a Hann window and Accelerate's real FFT, are summed into the
// bands and published, so at 48 kHz about 47 times a second. Plain C, so harness/visualiser/ runs it on
// the Mac.
//
// Threading: SGRSpectrumPrepare on the main thread, once, before anything is fed. SGRSpectrumFeed on the
// render thread only, one thread at a time: it allocates nothing and takes no lock. SGRSpectrumRead from
// any thread. What it reads can mix two analyses, a band from each, which nothing drawn can show.
//
// A look that wants the bands feeds them itself: SGAudioSetOutputReader (Shared/AudioEffects) takes one
// reader and hands it what Spotify plays, mixed to mono, so only the player on screen installs it.
#import <stdint.h>

enum { SGRSpectrumBands = 24 };
// What a band reads with nothing in it, and the least SGRSpectrumRead hands out.
#define SGRSpectrumFloor (-100.0f)

// Makes the FFT's tables. Repeat calls do nothing. Lives as long as the process: the render thread may be
// in SGRSpectrumFeed at any time.
void SGRSpectrumPrepare(void);
// Samples, mono, at `sampleRate`. A new rate starts the window over. Does nothing before SGRSpectrumPrepare.
void SGRSpectrumFeed(const float *samples, uint32_t count, double sampleRate);
// The last levels into `levels`, low band first; answers how many analyses there have been, so a caller
// can tell when nothing new came (paused, or the tap never ran).
uint64_t SGRSpectrumRead(float levels[SGRSpectrumBands]);
