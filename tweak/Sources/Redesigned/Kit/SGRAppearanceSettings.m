#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "SGRAccent.h"

// The redesign's rows of the Appearance page (App/Pages.m): the color in effect, which opens the picker, and the
// plain checkmark. The presets are the strip above the rows (SGRAccentStrip.m); a color stored from the picker is
// one of the strip's own and the last color picked, kept for the picker to start from. AMOLED has no row: the
// redesign is always black.
NSArray<SGModRow *> *SGRAppearanceRows(void) {
    SGModRow *colour = SGStatActionRow(@"Accent color", nil, ^NSString *{ return [NSString stringWithFormat:@"#%06lX", (long)SGRAccentRGB()]; }, ^{
        SGPickColor(@"Accent color", SGRAccentRGB(), ^(NSInteger rgb) {
            SGSetInt(SGRKeyAccent, rgb);
            SGSetInt(SGRKeyAccentCustom, rgb);
        });
    });
    colour.swatch = ^UIColor *{ return SGColorRGB(SGRAccentRGB()); };
    return @[
        SGWithSymbol(colour, @"eyedropper"),
        SGWithSymbol(SGOptionRow(@"Plain checkmark", @"A saved song's tick without its circle, in the accent", SGRKeyPlainCheck), @"checkmark"),
    ];
}
