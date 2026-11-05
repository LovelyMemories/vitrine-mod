// The redesign's Player page in Mod Settings (App/Pages.m opens it in place of the native look's).
//
// It leads with a card of the player as the now playing track shows on it, drawn the way the newer build of this
// mod draws it: the background chosen on the page edge to edge, the grabber and the two glass buttons at the top,
// the cover in the middle, the album, the title and the artist (gliding when too long) under it, the slider with
// how far the track has played and how much is left, and the foot with its three buttons. The progress is where
// the track was when the page appeared. With no track, the card shows the last one played
// (Shared/Player/SGLastTrack.h), its cover fetched and its Canvas looked up as the playing one's would be, and
// with none ever played, Not Playing over a gradient of the accent.
//
// The background is the player's own: a field of the same kind (Still, Colors, Fluid), for Animated
// the clip the player is playing (SGRPlayerMotionPreview) in place of the field, or, while the player has
// none, the playing track's clip looked up for the card while it is on screen, Fluid until it comes in and
// for a track with none, as in the player; the clip crosses over the field as it arrives, its poster first
// while its video decodes. And for Visualizer the hills over Fluid held still (SGRPlayerVisualiserPreview),
// moving with the song. It moves under the field's own conditions (in a window, Spotify in front, Reduce
// Motion and Low Power Mode off). Under the card a segmented control picks the background, all five of
// them: the names are one word each, each segment as wide as its name, so they fit side by side at an iPhone's
// width, and every choice stays one tap away with the card showing it at once. A note under the control says what the
// choice does; it is given the room of the longest note, so the rows under it hold still as it changes.
//
// Under the header: the rows that follow the choice (Animated's sources and its Low Data Mode switch; Fluid's
// five sliders and their Reset, which the card and the player follow as they move, SGRFluid.h), the Mini
// player section (Redesigned/NowPlayingBar/NowPlayingBarSettings.m), then the sections either look shares.
//
// Threading: main thread only.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Redesigned/Kit/SGRFluid.h"
#import "Redesigned/Kit/SGShader.h"
#import <CoreImage/CoreImage.h>
#import "Redesigned/NowPlayingBar/NowPlayingBar.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Shared/Player/SGLastTrack.h"
#import "Shared/Player/PlayerSettings.h"
#import "Shared/Player/SpeedPitch.h"
#import "Player.h"
#import "PlayerPresetStrip.h"
#import "PlayerBackgroundStrip.h"

// The printed cover: dithered and cut down to a few levels, the look the player gives a song with no moving
// artwork of its own. Worked out once per picture and kept; a cover is 300 points wide, so this is one pass.
static UIImage *printedCover(UIImage *image) {
    if (!image.CGImage) return image;
    static NSCache *cache;
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 8;
        context = [CIContext contextWithOptions:nil];
    });
    NSValue *key = [NSValue valueWithNonretainedObject:image];
    UIImage *kept = [cache objectForKey:key];
    if (kept) return kept;
    CIImage *input = [CIImage imageWithCGImage:image.CGImage];
    // Cut to a few levels and nothing else: the dither that came with it read as grain on a cover this size, which is
    // not what the look wants.
    CIFilter *posterise = [CIFilter filterWithName:@"CIColorPosterize"];
    [posterise setValue:input forKey:kCIInputImageKey];
    [posterise setValue:@6 forKey:@"inputLevels"];
    CIImage *out = posterise.outputImage ?: input;
    CGImageRef made = [context createCGImage:out fromRect:out.extent];
    UIImage *printed = made ? [UIImage imageWithCGImage:made scale:image.scale orientation:image.imageOrientation] : image;
    if (made) CGImageRelease(made);
    [cache setObject:printed forKey:key];
    return printed;
}

// The card is the player screen drawn small, as the newer build of this mod draws it: the grabber and the two
// glass buttons at the top, the cover in the middle, the album, the title and the artist under it, the slider
// with its two times, and the foot with its three buttons. Its height is a share of its width, kept in bounds.
static const CGFloat kCardAspect = 1.34, kCardMinHeight = 400, kCardMaxHeight = 560;
static const CGFloat kCardRadius = 26;   // continuous, the radius of the page's own cards and then some
static const CGFloat kCardPadding = 16;

// A song's time, as the player writes it.
static NSString *clockText(double seconds) {
    if (!isfinite(seconds) || seconds < 0) return @"0:00";
    NSInteger total = (NSInteger)lround(seconds);
    return [NSString stringWithFormat:@"%ld:%02ld", (long)(total / 60), (long)(total % 60)];
}

// What each background does, in SGRPlayerBackgroundKind's order.
static NSArray<NSString *> *backgroundNotes(void) {
    return @[
        @"The cover, blurred and held still.",
        @"The cover's colors, drifting slowly.",
        @"The cover itself, blurred and slowly turning. It rests while a song is paused.",
        @"The song's Canvas or the album's moving cover, else Fluid. The player's ⋯ menu switches between this, Fluid and Visualizer.",
        @"The song's sound as gentle hills in the cover's colors, over Fluid held still. They settle while a song is paused.",
        @"The cover's colors as a few soft blobs, drifting and breathing. It rests while a song is paused.",
        @"Nothing at all: the app's own black, for a screen that saves by it.",
        @"Whatever the song has: its animated artwork, or the Visualizer while it has none.",
    ];
}

@interface SGRPlayerShowcase : UIView <SGPlayerStateObserver>
- (void)reloadTrack;
- (void)reloadBackgroundAnimated:(BOOL)animated;
@end

@implementation SGRPlayerShowcase {
    SGRArtworkField *_field;
    SGAmbientView *_ambient;
    UIImageView *_printed;   // the cover printed, for Animated without a clip
    UIView *_motion, *_visualiser;
    UIImageView *_cover;
    SGMarqueeLabel *_title, *_artist;
    UIView *_progress, *_progressFill;
    UIView *_grabber, *_close, *_more, *_foot;
    UILabel *_album, *_elapsed, *_remaining;
    NSMutableArray<UIView *> *_footButtons;
    CGFloat _position;
    NSString *_artworkOf;   // the last track whose cover the card asked for
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.clipsToBounds = YES;
    self.layer.cornerRadius = kCardRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;
    self.backgroundColor = SGRNeutralField();
    self.userInteractionEnabled = NO;
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitImage;
    self.accessibilityLabel = @"Player preview";

    _field = [[SGRArtworkField alloc] initWithFrame:frame];
    _field.showsBackdrop = YES;
    [self addSubview:_field];

    // The Fluid background on the card: the newer build's ambient field, drawn by the shader in the cover's own
    // two colours, over the field. Where Metal cannot, the field's own Core Animation Fluid is what shows.
    // The card's Fluid is the field's own: a Metal view inside a card the page animates and re-lays out took the
    // app down in -[CALayer superlayer] under UIKit's animation machinery twice, so no Metal in a settings card
    // until that path is safe. The shader still draws the player itself (grain, hills), where nothing animates the
    // view it sits in.
    if (NO && [SGAmbientView metalAmbientAvailable]) {
        _ambient = [[SGAmbientView alloc] initWithFrame:frame];
        _ambient.amount = 0.25;
        // Its five numbers are Fluid's, read as it draws: the Adjust page's sliders move this field too.
        _ambient.followsFluid = YES;
        _ambient.hidden = YES;
        if (_ambient) [self addSubview:_ambient];
    }

    // The printed cover, when Animated has no clip to show: it stands where the field would.
    _printed = [UIImageView new];
    _printed.contentMode = UIViewContentModeScaleAspectFill;
    _printed.clipsToBounds = YES;
    _printed.hidden = YES;
    [self addSubview:_printed];

    // The player's own chrome: the grabber it is pulled down by, and the two glass buttons beside it.
    _grabber = [UIView new];
    _grabber.backgroundColor = [UIColor colorWithWhite:1 alpha:0.35];
    _grabber.layer.cornerRadius = 2;
    _footButtons = [NSMutableArray array];
    [self addSubview:_grabber];
    _close = [self glassButton:@"chevron.down"];
    _more = [self glassButton:@"ellipsis"];
    [self addSubview:_close];
    [self addSubview:_more];

    _cover = [UIImageView new];
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    _cover.clipsToBounds = YES;
    _cover.layer.cornerRadius = 8;
    _cover.layer.cornerCurve = kCACornerCurveContinuous;
    _cover.tintColor = SGRTertiary();
    _cover.backgroundColor = SGRSolidGlassFill();
    _cover.preferredSymbolConfiguration = [UIImageSymbolConfiguration configurationWithPointSize:22 weight:UIImageSymbolWeightRegular];
    [self addSubview:_cover];

    // The card reads as one image; the words glide as the player's own do, and the album names what it is from.
    _album = [UILabel new];
    _album.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    _album.textColor = SGRTertiary();
    _album.textAlignment = NSTextAlignmentCenter;
    _album.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_album];

    _title = [SGMarqueeLabel new];
    _title.textColor = SGRPrimary();
    _title.font = [UIFont systemFontOfSize:21 weight:UIFontWeightSemibold];
    _title.textAlignment = NSTextAlignmentCenter;
    _title.isAccessibilityElement = NO;
    [self addSubview:_title];
    _artist = [SGMarqueeLabel new];
    _artist.textColor = SGRSecondary();
    _artist.font = [UIFont systemFontOfSize:15];
    _artist.textAlignment = NSTextAlignmentCenter;
    _artist.isAccessibilityElement = NO;
    [self addSubview:_artist];

    // The player's slider as it is drawn at rest: a track, and in it a fill up to where the song is.
    _progress = [UIView new];
    _progress.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
    _progress.clipsToBounds = YES;
    _progressFill = [UIView new];
    _progressFill.backgroundColor = SGRPrimary();
    [_progress addSubview:_progressFill];
    [self addSubview:_progress];

    _elapsed = [self timeLabel];
    _remaining = [self timeLabel];
    _remaining.textAlignment = NSTextAlignmentRight;

    // Under all of it, the player's foot: the speaker, the queue and the lyrics.
    _foot = [UIView new];
    [self addSubview:_foot];
    for (NSString *symbol in @[@"hifispeaker", @"list.bullet", @"quote.bubble"]) {
        UIImageView *glyph = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
        glyph.tintColor = SGRSecondary();
        glyph.contentMode = UIViewContentModeScaleAspectFit;
        glyph.tag = 7;
        [_foot addSubview:glyph];
        [_footButtons addObject:glyph];
    }

    SGAddPlayerStateObserver(self);
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(artworkChanged) name:SGRNowPlayingArtworkDidChangeNotification object:nil];
    [self reloadTrack];
    [self reloadBackgroundAnimated:NO];
    return self;
}

- (UIView *)glassButton:(NSString *)symbol {
    UIView *button = [UIView new];
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.14];
    button.layer.cornerRadius = 15;
    button.layer.cornerCurve = kCACornerCurveContinuous;
    UIImageView *glyph = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    glyph.tintColor = [UIColor colorWithWhite:1 alpha:0.85];
    glyph.contentMode = UIViewContentModeScaleAspectFit;
    glyph.tag = 7;
    [button addSubview:glyph];
    return button;
}

- (UILabel *)timeLabel {
    UILabel *label = [UILabel new];
    label.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
    label.textColor = SGRTertiary();
    [self addSubview:label];
    return label;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)playerStateDidChange:(SPTPlayerState *)state {
    [self reloadTrack];
}

- (void)artworkChanged {
    NSString *identity = nil;
    UIImage *image = SGRNowPlayingArtwork(NULL, &identity);
    if (image) [self showArtwork:image identity:identity];
}

// The cover and the field from `image`, or from the placeholder for nil.
- (void)showArtwork:(UIImage *)image identity:(NSString *)identity {
    static UIImage *placeholder;
    static UIColor *tint;
    if (!image && (!placeholder || ![tint isEqual:SGGreen()])) {
        tint = SGGreen();
        placeholder = SGPlaceholderArtwork(tint);
    }
    _cover.image = image ?: placeholder;
    _cover.contentMode = UIViewContentModeScaleAspectFill;
    [_field setArtwork:_cover.image identity:image ? identity : @"placeholder" animated:self.window != nil];

    // The ambient field takes the cover's own two colours, as the player's background does: the colour along its
    // bottom edge for the light, the field colour made from it for the shade.
    if (_ambient) {
        __weak SGRPlayerShowcase *weakSelf = self;
        [SGRPalette paletteForImage:_cover.image request:(SGRPaletteRequest){0} completion:^(SGRPalette *palette) {
            SGRPlayerShowcase *showcase = weakSelf;
            if (!palette.edgeColor || !showcase) return;
            showcase->_ambient.topColor = palette.edgeColor;
            showcase->_ambient.bottomColor = palette.fieldColor ?: palette.edgeColor;
        }];
    }
}

// The track, where it is and whether it plays, read again.
- (void)reloadTrack {
    SPTPlayerState *state = SGPlayerState();
    SGShownTrack *shown = SGShownTrackNow();
    _title.text = shown.title ?: @"Not Playing";
    _artist.text = shown.artist ?: @"";
    _album.text = shown.album.length ? shown.album.uppercaseString : @"";
    _position = shown.current && state.duration > 0 ? MIN(1, MAX(0, state.position / state.duration)) : 0;
    _elapsed.text = clockText(shown.current ? state.position : 0);
    _remaining.text = clockText(shown.current && state.duration > 0 ? state.duration - state.position : 0);
    // The clip covers the field, and the hills move over it, which then holds still, as in the player.
    _field.motionHeld = state.isPaused || _motion != nil || _visualiser != nil;
    // A paused song holds the ambient field still too, as it holds the field.
    _ambient.moving = !_ambient.hidden && !state.isPaused;
    if (shown.current && SGRNowPlayingArtwork(NULL, NULL)) {
        [self artworkChanged];
    } else if (!shown.current && shown.artworkURL) {
        // The last track's cover, the placeholder until it comes.
        NSString *uri = shown.uri;
        if (![_artworkOf isEqualToString:uri]) [self showArtwork:nil identity:nil];
        _artworkOf = uri;
        __weak SGRPlayerShowcase *weakSelf = self;
        SGShownTrackArtwork(shown, ^(UIImage *image) {
            SGRPlayerShowcase *showcase = weakSelf;
            SGShownTrack *now = SGShownTrackNow();
            if (image && !now.current && [now.uri isEqualToString:uri]) [showcase showArtwork:image identity:[@"last:" stringByAppendingString:uri]];
        });
    } else {
        // Nothing ever played, or the playing track's cover still coming.
        _artworkOf = nil;
        [self showArtwork:nil identity:nil];
    }
    [self setNeedsLayout];
}

// The card on screen with Animated and no clip in it: one is looked up, and shown once it is in.
- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.window && !_motion && SGRPlayerBackground() == SGRPlayerBackgroundAnimated) [self reloadBackgroundAnimated:NO];
}

// The background chosen, read again; a new one crosses over when animated. The clip is the one playing, or
// looked up, when this is called: a track changed while the page shows keeps the last one until the page
// appears again. A clip is looked up only while the card is in a window.
- (void)reloadBackgroundAnimated:(BOOL)animated {
    // The card shows what the player will: Auto resolved to the track in it.
    SGRPlayerBackgroundKind kind = SGRPlayerBackground();
    if (kind == SGRPlayerBackgroundAuto) kind = SGPlayerMenuAnimatedArtwork() ? SGRPlayerBackgroundAnimated : SGRPlayerBackgroundVisualiser;
    __weak SGRPlayerShowcase *weakSelf = self;
    void (^arrived)(void) = !self.window ? nil : ^{
        SGRPlayerShowcase *showcase = weakSelf;
        if (showcase.window && !showcase->_motion && SGRPlayerBackground() == SGRPlayerBackgroundAnimated) [showcase reloadBackgroundAnimated:YES];
    };
    void (^apply)(void) = ^{
        // Fluid is the shader's on this card where the device has Metal: the ambient field in the cover's own
        // colours, which is what the newer build shows. The field keeps its own Fluid for every other use, and
        // stands in here where Metal cannot.
        BOOL shaderFluid = self->_ambient != nil && kind == SGRPlayerBackgroundFluid;
        self->_ambient.hidden = !shaderFluid;
        self->_ambient.moving = shaderFluid && !SGPlayerState().isPaused;
        self->_field.hidden = shaderFluid;
        self->_field.flows = kind == SGRPlayerBackgroundColours;
        self->_field.fluid = !shaderFluid && (kind == SGRPlayerBackgroundFluid || kind == SGRPlayerBackgroundAnimated || kind == SGRPlayerBackgroundVisualiser);
        self->_field.aurora = kind == SGRPlayerBackgroundAurora;
        self->_motion.alpha = 0;
        self->_motion = kind == SGRPlayerBackgroundAnimated ? SGRPlayerMotionPreview(arrived) : nil;
        if (self->_motion) [self insertSubview:self->_motion aboveSubview:self->_field];
        self->_visualiser.alpha = 0;
        self->_visualiser = kind == SGRPlayerBackgroundVisualiser ? SGRPlayerVisualiserPreview() : nil;
        if (self->_visualiser) [self insertSubview:self->_visualiser aboveSubview:self->_field];
        BOOL printed = kind == SGRPlayerBackgroundAnimated && self->_motion == nil;
        self->_printed.hidden = !printed;
        if (printed) {
            self->_printed.image = printedCover(self->_cover.image);
            SGLog(@"artwork: printed cover, no clip for this song");
        }
        self->_field.motionHeld = SGPlayerState().isPaused || self->_motion != nil || self->_visualiser != nil;
    };
    self.accessibilityValue = [SGRPlayerBackgroundNames()[(NSUInteger)kind] stringByAppendingString:@" background"];
    // A cross-fade of the whole card is a snapshot of its layer tree, and a Metal view's layer cannot be
    // snapshotted that way: with the ambient field in the card the change goes in plainly, and its colours and
    // rate change under the finger instead.
    // No cross-fade of the card: a transition snapshots its layer tree, and doing that while the field, the clip or
    // the printed cover changes underneath took the app down in UIKit's rendering three times. The change goes in
    // plainly, in one frame.
    apply();
    [self setNeedsLayout];
}

// The clip runs from the card's top at its width, as in the player, and its blur comes in from the
// seam under the controls, which on a card this short is over its foot, under the words.
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.bounds;
    CGFloat w = bounds.size.width, h = bounds.size.height;
    _field.frame = bounds;
    _field.backdropHeight = h;
    _printed.frame = bounds;
    _ambient.frame = bounds;
    _motion.frame = bounds;
    _visualiser.frame = bounds;

    // The chrome at the top, then the cover in the middle of the card.
    _grabber.frame = CGRectMake(round((w - 36) / 2), 8, 36, 4);
    _close.frame = CGRectMake(16, 18, 30, 30);
    _more.frame = CGRectMake(w - 46, 18, 30, 30);
    for (UIView *button in @[_close, _more]) [button viewWithTag:7].frame = CGRectInset(button.bounds, 7, 7);

    CGFloat side = MIN(w * 0.56, h * 0.40);
    _cover.frame = CGRectMake(round((w - side) / 2), 64, side, side);

    // Under it the album, the title and the artist, then the slider with its two times.
    CGFloat textX = kCardPadding + 8, textWidth = w - 2 * textX;
    CGFloat albumHeight = ceil(_album.font.lineHeight), titleHeight = ceil(_title.font.lineHeight), artistHeight = ceil(_artist.font.lineHeight);
    _album.frame = CGRectMake(textX, CGRectGetMaxY(_cover.frame) + 12, textWidth, albumHeight);
    _title.frame = CGRectMake(textX, CGRectGetMaxY(_album.frame) + 2, textWidth, titleHeight);
    _artist.frame = CGRectMake(textX, CGRectGetMaxY(_title.frame) + 1, textWidth, artistHeight);
    CGFloat line = 4, progressTop = CGRectGetMaxY(_artist.frame) + 16;
    _progress.frame = CGRectMake(textX, progressTop, textWidth, line);
    _progress.layer.cornerRadius = line / 2;
    _progressFill.frame = CGRectMake(0, 0, round(textWidth * _position), line);
    _elapsed.frame = CGRectMake(textX, CGRectGetMaxY(_progress.frame) + 3, 60, 12);
    _remaining.frame = CGRectMake(CGRectGetMaxX(_progress.frame) - 60, CGRectGetMaxY(_progress.frame) + 3, 60, 12);

    // The foot, at the card's bottom edge.
    _foot.frame = CGRectMake(0, h - 46, w, 24);
    for (NSUInteger i = 0; i < _footButtons.count; i++) {
        CGFloat x = i == 0 ? 40 : i == 1 ? round(w / 2 - 10) : w - 60;
        _footButtons[i].frame = CGRectMake(x, 2, 20, 20);
    }
}

@end

#pragma mark - the page

@interface SGRPlayerPage : SGModPage
@property (nonatomic, strong) SGRPlayerShowcase *showcase;
@property (nonatomic, strong) SGRPlayerBackgroundStrip *backgrounds;
@property (nonatomic, strong) SGRFluidPresetStrip *presets;
@end

@implementation SGRPlayerPage {
    UIView *_header;
    UILabel *_note;
    // The Fluid field, drawn by the shader. It sits over the table rather than inside the card: a Metal layer inside
    // a view the page animates took the app down twice in -[CALayer superlayer], so the card keeps a plain field and
    // this is laid over its frame as the table scrolls.
    SGAmbientView *_overlay;
    NSString *_overlayArtwork;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _header = [UIView new];
    [_header addSubview:self.showcase];
    [_header addSubview:self.backgrounds];
    _note = [UILabel new];
    _note.font = SGSubtitleFont();
    _note.textColor = SGGrey();
    _note.numberOfLines = 0;
    [_header addSubview:_note];
    if (self.presets) [_header addSubview:self.presets];
    [self showNote];
    self.tableView.tableHeaderView = _header;

    // The shader's field stays out of the page: a Metal layer in it took the app down in UIKit's own rendering
    // (SIGSEGV under QuartzCore, from this page) three times. The card keeps its plain field.
    if (NO && [SGAmbientView metalAmbientAvailable]) {
        _overlay = [[SGAmbientView alloc] initWithFrame:CGRectZero];
        if (_overlay) {
            _overlay.followsFluid = YES;
            _overlay.userInteractionEnabled = NO;
            _overlay.layer.cornerRadius = kCardRadius;
            _overlay.layer.cornerCurve = kCACornerCurveContinuous;
            _overlay.clipsToBounds = YES;
            _overlay.hidden = YES;
            _overlay.alpha = 0.55;   // the card's cover and words are under it: the field shows through, not over
            [self.view insertSubview:_overlay aboveSubview:self.tableView];

        }
    }
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(overlayArtworkChanged)
                                               name:SGRNowPlayingArtworkDidChangeNotification object:nil];
    // The field follows the card as the page scrolls, without taking the table's own delegate methods.
    [self.tableView addObserver:self forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:NULL];
}

// The card's frame in the page, held over it: the field is as tall as the card and is cut with it, and it goes away
// with the card when the page scrolls it off or another background is picked.
- (void)layoutOverlay {
    if (!_overlay) return;
    BOOL fluid = SGRPlayerBackground() == SGRPlayerBackgroundFluid;
    CGRect frame = [self.showcase convertRect:self.showcase.bounds toView:self.view];
    _overlay.frame = frame;
    _overlay.hidden = !fluid || CGRectIsEmpty(CGRectIntersection(frame, self.view.bounds));
    _overlay.moving = !_overlay.hidden && !SGPlayerState().isPaused;
    if (!_overlay.hidden) [self.view bringSubviewToFront:_overlay];
}

// The colours the field is drawn in, from the cover playing: the palette's edge colour for the light and its field
// colour for the shade, as the player's own background takes them.
- (void)overlayArtworkChanged {
    // The identity comes back through an autoreleasing out-parameter, which an ivar's address cannot be.
    NSString *identity = nil;
    UIImage *image = SGRNowPlayingArtwork(NULL, &identity);
    if (!image || !_overlay) return;
    _overlayArtwork = identity;
    __weak SGRPlayerPage *weakSelf = self;
    [SGRPalette paletteForImage:image request:(SGRPaletteRequest){0} completion:^(SGRPalette *palette) {
        SGRPlayerPage *page = weakSelf;
        if (!page || !palette.edgeColor) return;
        page->_overlay.topColor = palette.edgeColor;
        page->_overlay.bottomColor = palette.fieldColor ?: palette.edgeColor;
    }];
}

- (void)showNote {
    _note.text = backgroundNotes()[(NSUInteger)SGRPlayerBackground()];
    [self.view setNeedsLayout];
}

// The header keeps the height it is given, so it is sized here and given back to the table only when that
// changes (a table header set on every pass lays the table out again forever). The note's room is that of
// the longest note at this width, so picking a background never moves the rows.
- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    _note.font = SGSubtitleFont();
    CGFloat width = table.bounds.size.width, inset = table.layoutMargins.left;
    CGFloat cardWidth = width - 2 * inset;
    CGFloat cardHeight = round(MIN(kCardMaxHeight, MAX(kCardMinHeight, cardWidth * kCardAspect)));
    self.showcase.frame = CGRectMake(inset, 16, cardWidth, cardHeight);
    CGFloat controlHeight = MAX(148, ceil([self.backgrounds intrinsicContentSize].height));
    self.backgrounds.frame = CGRectMake(inset, CGRectGetMaxY(self.showcase.frame) + 12, cardWidth, controlHeight);

    CGFloat noteWidth = cardWidth - 2 * 4, room = 0;
    UILabel *measure = [UILabel new];
    measure.font = _note.font;
    measure.numberOfLines = 0;
    for (NSString *text in backgroundNotes()) {
        measure.text = text;
        room = MAX(room, ceil([measure sizeThatFits:CGSizeMake(noteWidth, CGFLOAT_MAX)].height));
    }
    CGFloat noteHeight = ceil([_note sizeThatFits:CGSizeMake(noteWidth, CGFLOAT_MAX)].height);
    CGFloat noteTop = CGRectGetMaxY(self.backgrounds.frame) + 8;
    _note.frame = CGRectMake(inset + 4, noteTop, noteWidth, noteHeight);
    CGFloat bottom = noteTop + room;
    // The looks are a card of their own under the note, and only while the field is the Fluid one.
    self.presets.hidden = SGRPlayerBackground() != SGRPlayerBackgroundFluid;
    if (!self.presets.hidden) {
        CGSize want = self.presets.intrinsicContentSize;
        CGFloat stripWidth = MIN(cardWidth, want.width), stripHeight = want.height;
        self.presets.frame = CGRectMake(inset, bottom + 6, stripWidth, stripHeight);
        bottom = CGRectGetMaxY(self.presets.frame);
    }
    CGSize size = CGSizeMake(width, bottom);
    if (CGSizeEqualToSize(_header.bounds.size, size)) return;
    _header.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = _header;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self layoutOverlay];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:@"contentOffset"]) { [self layoutOverlay]; return; }
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)dealloc {
    [self.tableView removeObserver:self forKeyPath:@"contentOffset"];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self overlayArtworkChanged];
    // The player's ⋯ menu can switch Animated and Fluid while the page is away.
    self.backgrounds.artwork = SGRNowPlayingArtwork(NULL, NULL);
    [self.backgrounds setSelected:SGRPlayerBackground()];
    [self showNote];
    [self.showcase reloadTrack];
    [self.showcase reloadBackgroundAnimated:NO];
}

- (void)backgroundPicked:(NSInteger)index {
    SGSetInt(SGRKeyPlayerBackground, index);
    [self layoutOverlay];
    [self.showcase reloadBackgroundAnimated:YES];
    [self showNote];
    [self refreshVisibility];
}

@end

// One of Fluid's settings on a slider, written out with `unit` after the number.
static SGModRow *fluidSlider(NSString *title, SGRFluidSetting setting, NSString *unit) {
    SGRFluidLimits l = SGRFluidLimitsOf(setting);
    return SGSliderRow(title, nil, l.least, l.most, l.step, ^double { return SGRFluidValue(setting); },
                       ^(double value) { SGRSetFluidValue(setting, lround(value)); },
                       ^NSString *(double value) { return [NSString stringWithFormat:@"%.0f%@", value, unit]; });
}

// Fluid's own page, the way the newer build gives it one (SGRPlayerAdjustPage): the six numbers the field is made
// of, and their reset. The Player page keeps the card, the backgrounds and the looks; these live where they are
// read out at length rather than in a fold of the page.
UIViewController *SGRPlayerAdjustPage(void) {
    __block __weak UITableViewController *weakPage;
    SGModRow *reset = SGActionRow(@"Reset", nil, ^{
        SGRResetFluidSettings();
        [weakPage.tableView reloadData];   // the sliders at once, rather than at the page's next tick
    });
    reset.color = SGRed();
    NSArray<SGModRow *> *fluid = @[
        fluidSlider(@"Speed", SGRFluidSpeed, @"%"), fluidSlider(@"Warp", SGRFluidWarp, @"%"), fluidSlider(@"Blur", SGRFluidBlur, @""),
        fluidSlider(@"Saturation", SGRFluidSaturation, @"%"), fluidSlider(@"Brightness", SGRFluidBrightness, @"%"),
        fluidSlider(@"Grain", SGRFluidGrain, @"%"), reset,
    ];
    SGModPage *page = [[SGModPage alloc] initWithTitle:@"Adjust" intro:nil sections:@[
        SGNotedSection(nil, fluid, @"Brightness above 100% can make white text harder to read. A paused song holds the "
                                   @"background still. Animated and Visualizer use these where they show Fluid."),
    ] footer:nil];
    weakPage = page;
    return page;
}

// Their words for it, when a look is picked: a small pill at the foot of the page that says "Fluid artwork is
// picked" and goes away by itself, the way the newer build says it.
static void sayPicked(UIView *host) {
    if (!host) return;
    UILabel *pill = [UILabel new];
    pill.text = @"Fluid artwork is picked";
    pill.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    pill.textColor = UIColor.whiteColor;
    pill.textAlignment = NSTextAlignmentCenter;
    pill.backgroundColor = [UIColor colorWithWhite:0.16 alpha:0.95];
    pill.layer.cornerRadius = 16;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.clipsToBounds = YES;
    pill.alpha = 0;
    CGFloat width = MIN(240, CGRectGetWidth(host.bounds) - 48);
    pill.frame = CGRectMake(round((CGRectGetWidth(host.bounds) - width) / 2),
                            CGRectGetHeight(host.bounds) - host.safeAreaInsets.bottom - 96, width, 32);
    pill.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [host addSubview:pill];
    [UIView animateWithDuration:0.18 animations:^{ pill.alpha = 1; } completion:^(BOOL done) {
        [UIView animateWithDuration:0.3 delay:1.2 options:0 animations:^{ pill.alpha = 0; } completion:^(BOOL gone) {
            [pill removeFromSuperview];
        }];
    }];
}

UIViewController *SGRPlayerSettingsPage(NSArray *more) {
    __block __weak SGRPlayerPage *weakPage;
    SGRPlayerShowcase *showcase = [[SGRPlayerShowcase alloc] initWithFrame:CGRectMake(0, 0, 320, kCardMinHeight)];
    SGRPlayerBackgroundStrip *backgrounds = [[SGRPlayerBackgroundStrip alloc] initWithFrame:CGRectMake(0, 0, 320, 148)
                                                                               names:SGRPlayerBackgroundNames()
                                                                              picked:^(NSInteger index) {
        [weakPage backgroundPicked:index];
    }];
    backgrounds.artwork = SGRNowPlayingArtwork(NULL, NULL);

    SGModRow *lowData = SGOptionRow(@"Download in Low Data Mode", @"Up to about 7 MB a song", SGKeyMotionLowData);
    lowData.visible = ^BOOL { return SGRPlayerBackground() == SGRPlayerBackgroundAnimated; };
    // The sources of the moving artwork, shown whatever the background is: they are what Animated and the
    // player's own clip lookups read, and the newer build keeps the row in sight.
    SGModRow *sources = SGMotionSourcesRow();

    // The looks as cards, above the rows: picking one lays its six settings over everything at once, and the
    // sliders on Adjust then show what it set.
    __block SGRFluidPresetStrip *strip = nil;
    strip = [[SGRFluidPresetStrip alloc] initWithFrame:CGRectMake(0, 0, 320, 152) names:SGRFluidPresetNames()
                                               picked:^(NSInteger index) {
        SGRApplyingFluidPreset((SGRFluidPreset)index);
        sayPicked(weakPage.view);
        [weakPage.tableView reloadData];
    }];
    // The six numbers are a page of their own (SGRPlayerAdjustPage), one row from here.
    SGModRow *adjust = SGPageRow(@"Adjust", ^{ return SGRPlayerAdjustPage(); });
    adjust.subtitle = @"Fluid's speed, warp, blur, saturation, brightness and grain";

    NSMutableArray<SGModSection *> *sections = [NSMutableArray arrayWithObjects:
        SGSection(nil, @[sources, lowData]),

        SGSection(nil, @[adjust]),   // no symbol: a row with one is drawn as a tile, which took the page down
        SGNotedSection(@"Buttons", @[SGShownRow(@"Video button", @"Switch to video from the cover", SGKeyHideVideoSwitch)],
                       @"The video button appears over the cover while the song has a video."),
        SGNotedSection(@"Controls", @[SGSwitchRow(@"Volume slider", @"A slider under the controls for this iPhone, or the speaker's", SGRKeyPlayerVolume),
                                      SGOptionRow(@"Follow the cover", nil, SGRKeyPlayerFollowsCover),
                                      SGSwitchRow(@"Only the music", nil, SGRKeyPlayerZen)],
                       @"Volume puts a slider under the controls for this iPhone, or the speaker's while Spotify plays on another device. "
                       @"Follow the cover paints the like, shuffle and repeat in the color of the song playing. Only the music: a long "
                       @"press on the cover takes the rest of the player off it, the title, controls and footer among them, and leaves the "
                       @"artwork and the lyric line; a long press again brings it back."),
        SGNotedSection(@"Mini player", SGRNowPlayingBarRows(),
                       @"Apple Music style moves the now playing bar in between two tabs as you scroll down."), nil];
    [sections addObjectsFromArray:more];
    // Fluid, Animated and Visualizer share the field (PlayerMotion.x reads the choice on every track, PlayerVisualiser.m
    // on the field's layout); Still and Colors are a field of another kind, made once a launch (PlayerField.x).
    NSString *footer = @"Fluid, Animated and Visualizer change with the next song. Still, Colors, Aurora, Black, Auto and Hide on the player apply after you restart Spotify.";
    SGRPlayerPage *page = [[SGRPlayerPage alloc] initWithTitle:@"Player" intro:nil sections:sections footer:footer];
    weakPage = page;
    page.showcase = showcase;
    page.presets = strip;
    page.backgrounds = backgrounds;
    return page;
}
