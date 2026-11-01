// Two things are done to a label's text where it is set, all by exact match so nothing else changes: the
// account row's free-plan pill becomes Premium, the account's old name reads as the build's nickname, and the
// mod's own wording is turned into the chosen language (Core/SGLanguage.h) — the last only on the mod's own
// screens, never on Spotify's. The subscription card's tab is left as Spotify wrote it ("Подписка").
#import <UIKit/UIKit.h>
#import "Core/SGCore.h"

static NSString *sg_plan(NSString *text) {
    if (text.length < 5) return text;
    if ([text isEqualToString:@"Бесплатная версия Spotify"] || [text isEqualToString:@"Spotify Free"]) return @"Premium";
    // The account's own name, wherever it sits in a short line ("Eevee", "Eevee Premium"), in any case: the
    // subscription card, the profile, the side drawer. A credit to EeveeSpotify is not the account's name and is
    // left where it is, and a long line is never looked into, so only the name's own labels pay for this.
    if (text.length <= 24) {
        NSRange name = [text rangeOfString:@"Eevee" options:NSCaseInsensitiveSearch];
        BOOL credit = [text rangeOfString:@"EeveeSpotify" options:NSCaseInsensitiveSearch].location != NSNotFound;
        if (name.location != NSNotFound && !credit) {
            return [text stringByReplacingCharactersInRange:name withString:@"DrippyPsycho"];
        }
    }
    return text;
}

// Whether this label sits on one of the mod's screens: the walk looks for any view or controller of the
// mod's in the chain, not the first controller, since a label in a navigation bar would stop at the
// navigation controller above it and the mod's row in Spotify's own settings list has no mod controller at
// all. Everything the mod builds starts with "SG".
static BOOL sg_ours(UIResponder *responder) {
    for (int i = 0; responder && i < 32; i++, responder = responder.nextResponder) {
        if ([NSStringFromClass(responder.class) hasPrefix:@"SG"]) return YES;
    }
    return NO;
}

static NSString *sg_text(UIResponder *owner, NSString *text) {
    NSString *planned = sg_plan(text);
    // SGLocalized answers the same string when the language is English or the table has no line for it, so
    // the walk below runs only for a text that would really change.
    NSString *translated = SGLocalized(planned);
    return translated != planned && sg_ours(owner) ? translated : planned;
}

%hook UILabel
- (void)setText:(NSString *)text {
    %orig(sg_text(self, text));
}
// A label can be given its text before it is in a page (a cell built off screen, the tour's cards): its
// controller is not in reach then, so the same swap is tried again when it reaches a window, where it is.
// Never while drawing: a text changed mid-draw keeps the layout measured for the old one and is cut short.
- (void)didMoveToWindow {
    %orig;
    NSString *text = self.text;
    if (!text.length) return;
    NSString *wanted = sg_text(self, text);
    if (wanted == text) return;
    // Once more through -setText:, which finds this text already in the asked-for language and leaves it.
    self.text = wanted;
}
- (void)setAttributedText:(NSAttributedString *)text {
    NSString *swapped = text ? sg_text(self, text.string) : nil;
    if (!text || [swapped isEqualToString:text.string]) {
        %orig;
        return;
    }
    NSMutableAttributedString *copy = [text mutableCopy];
    [copy replaceCharactersInRange:NSMakeRange(0, copy.length) withString:swapped];
    %orig(copy);
}
%end

%hook UIButton
- (void)setTitle:(NSString *)title forState:(UIControlState)state {
    %orig(sg_text(self, title), state);
}
%end

// A page's title is drawn by Spotify's own navigation bar: its label is not in the mod's view chain, so the walk
// above never reached it, and the page's header stayed English. It is turned where the page hands it over. The
// mod's own controllers are all named SG..., so Spotify's pages keep their titles.
%hook UIViewController
- (void)setTitle:(NSString *)title {
    %orig([NSStringFromClass(self.class) hasPrefix:@"SG"] ? SGLocalized(title) : title);
}
%end

%ctor {
    %init;
    // One line at launch, so a report of "it was Russian and came back English" can be told from a lost
    // setting: what was stored, and what the mod is reading.
    SGLog(@"language: %ld stored, %ld in use", (long)SGInt(SGKeyLanguage, 0), (long)SGLanguage());
}
