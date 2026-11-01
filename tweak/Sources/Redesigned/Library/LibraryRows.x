// Library redesign: the rows of Your Library and of a folder inside it, and the cards of its grid.
//
// Tree (trees/clean/library/03.txt:30-73, 06.txt:28-40): every cell of the list is a
// YourLibrarySwipeableCollectionViewCellContainer holding either a 402x80 row -- id=Playlist.Row.Library,
// Album.Row.Library or Podcast.Row.Library, all three an AutoLayoutStackView {16, 8} 370x64 of
// id=Artwork.Row.Library 64x64 r=4 and, 12pt after it, the title over its kind and its owner -- or a
// 112.67x161.33 card, id=Components.UI.CardLibrary, over id=Components.UI.CardLibrary.Artwork r=4.
//
// Two things are changed, both of them the Music app's library. The artwork takes the Kit's radius for its
// size with continuous corners, Spotify's 4pt being the square corner of its own look; an artist's picture
// already carries a radius half its side and is left the circle it is (r=32 in the trees, 2 of the 90 rows
// recorded). No hairline runs between the rows.
#import "Core/SGCore.h"
#import "Redesigned/Kit/SGRKit.h"
#import "Library.h"

// What a row leaves between its artwork and its text (03.txt:36 and :39: the artwork ends at 64, the text
// starts at 76). Nothing runs between one row and the next: the hairline the list lays under itself is cleared
// on every pass (SGRClearRowDividers, Kit/SGRRestyle.h).

static char kThumbKey, kCoverKey;

// Spotify gives a cover a square corner and an artist's picture a circle. Only the square becomes the Kit's.
static void roundCorners(UIView *artwork, CGFloat radius) {
    if (!artwork) return;
    CGFloat side = MIN(artwork.bounds.size.width, artwork.bounds.size.height);
    CALayer *layer = artwork.layer;
    if (side < 1 || layer.cornerRadius >= side / 2 - 0.5) return;
    if (layer.cornerRadius != radius) layer.cornerRadius = radius;
    if (layer.cornerCurve != kCACornerCurveContinuous) layer.cornerCurve = kCACornerCurveContinuous;
    if (!layer.masksToBounds) layer.masksToBounds = YES;
}

// The row's corner work done, and no hairline under it.
static void style(UIView *cell) {
    UIView *thumb = SGRFindByIdentifier(cell, @"Artwork.Row.Library", &kThumbKey);
    if (thumb) roundCorners(thumb, SGRRadiusThumb);
    else roundCorners(SGRFindByIdentifier(cell, @"Components.UI.CardLibrary.Artwork", &kCoverKey), SGRRadiusCover);
    SGRClearRowDividers(cell);

    // The first cell that held an artwork, so the line says what was found rather than what had not loaded yet.
    static BOOL logged;
    if (!logged && thumb && thumb.bounds.size.width > 1) {
        logged = YES;
        SGLog(@"redesign library: rows styled, first cell %@, thumbnail %@ at r=%.1f",
              NSStringFromCGSize(cell.bounds.size), NSStringFromCGSize(thumb.bounds.size), thumb.layer.cornerRadius);
    }
}

%hook _TtC21YourLibrary_CommonKit47YourLibrarySwipeableCollectionViewCellContainer
- (void)layoutSubviews {
    %orig;
    style((UIView *)self);
}
%end

%ctor {
    if (!SGRedesignedUI()) return;
    %init;
    SGRequireClasses(@[@"_TtC21YourLibrary_CommonKit47YourLibrarySwipeableCollectionViewCellContainer"]);
}
