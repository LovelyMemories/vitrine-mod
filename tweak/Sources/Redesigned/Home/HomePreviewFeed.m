#import "HomePreviewFeed.h"
#import "Core/SGCore.h"

@implementation SGRHomeFeedItem
@end

static __weak UICollectionView *sg_feed;

void SGRHomeFeedRemember(UIView *viewOfHome) {
    for (UIView *view = viewOfHome; view; view = view.superview) {
        if (![view isKindOfClass:UICollectionView.class]) continue;
        sg_feed = (UICollectionView *)view;
        return;
    }
}

// The picture a card draws: its largest image view that has one. A card still loading has none, and is skipped
// rather than shown as an empty frame.
static UIImage *pictureIn(UIView *view) {
    UIImage *best = nil;
    CGFloat bestArea = 0;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];
        [queue addObjectsFromArray:next.subviews];
        if (![next isKindOfClass:UIImageView.class] || next.hidden || next.alpha < 0.05) continue;
        UIImage *image = ((UIImageView *)next).image;
        if (!image) continue;
        CGFloat area = CGRectGetWidth(next.bounds) * CGRectGetHeight(next.bounds);
        if (area > bestArea) { bestArea = area; best = image; }
    }
    return best;
}

// The words under the picture, in the order they are laid out: the card's name, then what it is.
static NSArray<NSString *> *wordsIn(UIView *view) {
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:view];
    while (queue.count) {
        UIView *next = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (!next.isHidden && next.alpha > 0.05 && [next isKindOfClass:UILabel.class]) {
            NSString *text = ((UILabel *)next).text;
            if (text.length && ![words containsObject:text]) [words addObject:text];
        }
        [queue addObjectsFromArray:next.subviews];
    }
    return words;
}

NSArray<SGRHomeFeedItem *> *SGRHomeFeedItems(NSInteger most) {
    UICollectionView *feed = sg_feed;
    if (!feed || !feed.window || most <= 0) return @[];
    NSMutableArray<SGRHomeFeedItem *> *items = [NSMutableArray array];
    for (UICollectionViewCell *cell in feed.visibleCells) {
        if ((NSInteger)items.count >= most) break;
        if (CGRectGetWidth(cell.bounds) < 80 || CGRectGetHeight(cell.bounds) < 80) continue;   // a chip or a header
        UIImage *image = pictureIn(cell);
        if (!image) continue;
        NSArray<NSString *> *words = wordsIn(cell);
        SGRHomeFeedItem *item = [SGRHomeFeedItem new];
        item.image = image;
        item.title = words.count ? words[0] : @"";
        item.subtitle = words.count > 1 ? words[1] : @"";
        [items addObject:item];
    }
    return items;
}
