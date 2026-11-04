// The redesign's Albums page: a card of an album page as the switches below make it, Apple Music's animated
// covers and whether their downloads run in Low Data Mode, the restarts a change waits for, then what the
// redesign takes off an album's page and from under its tracks.
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Shared/AnimatedArtwork/AnimatedArtwork.h"
#import "Album.h"
#import "AlbumShowcase.h"

// The page with the card on top: the card keeps the height it is given, so it is sized here and handed to the
// table only when that changes (a table header set on every pass lays the table out again forever).
@interface SGRAlbumPage : SGModPage
@property (nonatomic, strong) SGRAlbumShowcase *showcase;
@end

@implementation SGRAlbumPage {
    UIView *_header;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _header = [UIView new];
    [_header addSubview:self.showcase];
    self.tableView.tableHeaderView = _header;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    UITableView *table = self.tableView;
    CGFloat width = table.bounds.size.width, inset = table.layoutMargins.left;
    CGFloat cardWidth = width - 2 * inset;
    self.showcase.frame = CGRectMake(inset, 16, cardWidth, round(cardWidth * 0.95));
    CGSize size = CGSizeMake(width, CGRectGetMaxY(self.showcase.frame) + 8);
    if (CGSizeEqualToSize(_header.bounds.size, size)) return;
    _header.frame = (CGRect){CGPointZero, size};
    table.tableHeaderView = _header;
}

@end

UIViewController *SGRAlbumSettingsPage(void) {
    SGRAlbumPage *page = [[SGRAlbumPage alloc] initWithTitle:@"Albums" intro:SGRestartNote sections:@[
        SGNotedSection(@"Apple Music", @[
            SGSwitchRow(@"Animated covers", @"At the top of an album that has one, about 5 MB each", SGRKeyAlbumMotion),
            SGOptionRow(@"Download in Low Data Mode", nil, SGKeyMotionLowData),
        ], @"Only the album's name is sent to Apple Music. A cover stays still in Low Power Mode."),
        SGSection(@"Hide on an album's page", @[
            SGSwitchRow(@"Repeated track artists", @"The artist under a track when it is the album's own", SGRKeyAlbumHideTrackArtists),
        ]),
        SGNotedSection(@"Hide under an album's tracks", @[
            SGSwitchRow(@"More by the artist", nil, SGRKeyAlbumHideMoreBy),
            SGSwitchRow(@"Related music videos", nil, SGRKeyAlbumHideVideos),
            SGSwitchRow(@"Concerts", nil, SGRKeyAlbumHideConcerts),
            SGSwitchRow(@"Merch", nil, SGRKeyAlbumHideMerch),
            SGSwitchRow(@"You might also like", nil, SGRKeyAlbumHideYouMightLike),
            SGSwitchRow(@"Everything else", @"Any other section Spotify sends", SGRKeyAlbumHideOther),
        ], @"Sections are told apart by their English names. With Spotify in another language, Everything else "
           @"covers them all."),
    ] footer:nil];
    page.showcase = [SGRAlbumShowcase new];
    return page;
}
