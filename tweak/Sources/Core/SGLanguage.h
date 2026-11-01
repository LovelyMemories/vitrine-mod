// The mod's own wording in the person's language. The app's strings are English literals where they are
// written; this turns the ones the table knows into Russian when Russian is picked, and leaves everything
// else — Spotify's own screens, anything not listed — exactly as it is. So a string added later shows in
// English until its line lands here, rather than showing nothing.
#import <Foundation/Foundation.h>

// 0 English, 1 Russian; read at launch like the other switches (Core/SGPrefs.h).
#define SGKeyLanguage @"spotifyglass.language"

NSInteger SGLanguage(void);
void SGLanguageChanged(void);   // after the choice moves, so the next read sees it

// `text` in the chosen language; `text` itself when it is English, unknown, or nil.
NSString *SGLocalized(NSString *text);
