#import "SGRAccentStrip.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"
#import "SGRAccent.h"

// -1 keeps Spotify's own green; the rest are the colors the redesign offers, Apple Music's red among them, then the
// colours picked lately, which is what the newer build's swatches keep.
static NSString *const kRecentKey = @"spotifyglass.redesign.accent.recent";

void SGRAccentRemember(NSInteger rgb) {
    if (rgb < 0 || rgb > 0xFFFFFF) return;
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSMutableArray<NSNumber *> *list = [[store arrayForKey:kRecentKey] mutableCopy] ?: [NSMutableArray array];
    [list removeObject:@(rgb)];
    [list insertObject:@(rgb) atIndex:0];
    while (list.count > 4) [list removeLastObject];
    [store setObject:list forKey:kRecentKey];
}

static NSArray<NSNumber *> *accentValues(void) {
    NSMutableArray<NSNumber *> *values = [@[@(-1), @(SGAppleMusicRed), @(SGRDefaultAccent), @(0x0A84FF), @(0xBF5AF2),
                                           @(0xFF375F), @(0xFF9F0A), @(0x64D2FF)] mutableCopy];
    for (NSNumber *recent in [NSUserDefaults.standardUserDefaults arrayForKey:kRecentKey] ?: @[]) {
        if (![values containsObject:recent]) [values addObject:recent];
    }
    return values;
}

@interface SGRAccentStripView : UIView
@end

@implementation SGRAccentStripView {
    UIView *_card;
    NSMutableArray<UIControl *> *_dots;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = UIColor.clearColor;
    _card = [UIView new];
    _card.backgroundColor = SGCardBackground();
    _card.layer.cornerRadius = 20;
    _card.layer.cornerCurve = kCACornerCurveContinuous;
    [self addSubview:_card];
    _dots = [NSMutableArray array];
    NSArray<NSNumber *> *values = accentValues();
    for (NSUInteger i = 0; i < values.count; i++) {
        NSInteger rgb = values[i].integerValue;
        UIControl *dot = [UIControl new];
        dot.tag = (NSInteger)i;
        dot.backgroundColor = rgb < 0 ? [UIColor colorWithRed:0x1D / 255.0 green:0xB9 / 255.0 blue:0x54 / 255.0 alpha:1]
                                     : SGColorRGB(rgb);
        dot.layer.cornerRadius = 15;
        [dot addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        dot.accessibilityLabel = rgb < 0 ? @"Spotify's own green" : @"Accent color";
        [_card addSubview:dot];
        [_dots addObject:dot];
    }
    [self paint];
    return self;
}

- (void)tapped:(UIControl *)dot {
    NSInteger rgb = accentValues()[(NSUInteger)dot.tag].integerValue;
    SGSetInt(SGRKeyAccent, rgb);
    // A pick is what the picker row comes back to: Spotify's own green is not one of them.
    if (rgb >= 0) SGSetInt(SGRKeyAccentCustom, rgb);
    SGRAccentRemember((NSInteger)rgb);
    [self paint];
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
}

// The ring is a border on the dot's own layer, drawn with the card's own corner so it reads as a ring and not a halo.
- (void)paint {
    NSInteger current = SGInt(SGRKeyAccent, SGRDefaultAccent);
    for (UIControl *dot in _dots) {
        NSInteger rgb = accentValues()[(NSUInteger)dot.tag].integerValue;
        BOOL on = rgb == current;
        dot.layer.borderWidth = on ? 2 : 0;
        dot.layer.borderColor = UIColor.whiteColor.CGColor;
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat width = CGRectGetWidth(self.bounds);
    _card.frame = CGRectMake(0, 0, width, 64);
    CGFloat inset = 14, count = (CGFloat)_dots.count;
    CGFloat room = width - 2 * inset;
    CGFloat step = count > 1 ? (room - 30) / (count - 1) : 0;
    for (NSUInteger i = 0; i < _dots.count; i++) {
        _dots[i].frame = CGRectMake(inset + i * step, 17, 30, 30);
    }
    [self paint];
}

@end

UIView *SGRAccentStrip(void) {
    SGRAccentStripView *strip = [[SGRAccentStripView alloc] initWithFrame:CGRectMake(0, 0, 320, 64)];
    return strip;
}
