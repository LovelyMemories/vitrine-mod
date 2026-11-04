#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"
#import "SGRAccent.h"
#import "SGRAccentStrip.h"

// The redesign's rows of the Appearance page (App/Pages.m): the color in effect, which opens the picker, and the
// plain checkmark. The presets are the strip above the rows (SGRAccentStrip.m); a color stored from the picker is
// one of the strip's own and the last color picked, kept for the picker to start from. AMOLED has no row: the
// redesign is always black.
NSArray<SGModRow *> *SGRAppearanceRows(void) {
    SGModRow *colour = SGStatActionRow(@"Accent color", nil, ^NSString *{ return [NSString stringWithFormat:@"#%06lX", (long)SGRAccentRGB()]; }, ^{
        SGPickColor(@"Accent color", SGRAccentRGB(), ^(NSInteger rgb) {
            SGSetInt(SGRKeyAccent, rgb);
            SGSetInt(SGRKeyAccentCustom, rgb);
            SGRAccentRemember(rgb);   // the strip keeps what has been picked lately, as the newer build's swatches do
        });
    });
    colour.swatch = ^UIColor *{ return SGColorRGB(SGRAccentRGB()); };
    // Their switch, in their words: the player's accent follows the cover of the song playing, and the colour picked
    // by hand is what it comes back to.
    SGModRow *cover = SGOptionRow(@"Accent from the cover", @"The player's accent colour can follow the cover of the song playing.", SGRKeyAccentFromCover);
    cover.changed = ^(BOOL on) { SGRAccentFromCoverSet(on); };
    return @[
        SGWithSymbol(cover, @"photo"),
        SGWithSymbol(colour, @"eyedropper"),
        SGWithSymbol(SGOptionRow(@"Plain checkmark", @"A saved song's tick without its circle, in the accent", SGRKeyPlainCheck), @"checkmark"),
    ];
}
