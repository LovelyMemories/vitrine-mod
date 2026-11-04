#import "AppIconStrip.h"
#import "Core/SGCore.h"
#import "Settings/SGModPage.h"
#import "Settings/SGPageStyle.h"

// Chroma's icons are not offered: the art is a build of its own, and this strip is Vitrine's.
static BOOL skipped(NSString *name) {
    return [name.lowercaseString containsString:@"chroma"];
}

static NSArray<NSString *> *iconNames(void) {
    NSDictionary *icons = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIcons"];
    NSDictionary *alternates = [icons isKindOfClass:NSDictionary.class] ? icons[@"CFBundleAlternateIcons"] : nil;
    if (![alternates isKindOfClass:NSDictionary.class]) return @[];
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (NSString *name in [alternates.allKeys sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
        if (!skipped(name)) [names addObject:name];
    }
    return names;
}

// The list holds NSNull where the app's own icon goes, since an array cannot hold nil. Everything that reads a
// name takes it through here first: NSNull is not a string, and asking it for one throws.
static NSString *nameOf(id name) {
    return [name isKindOfClass:NSString.class] ? name : nil;
}

static NSString *label(NSString *name) {
    name = nameOf(name);
    if (!name) return @"Default";
    // The icons are named SGAppIconArcsLight and the like: the prefix says nothing to a person, and a capital
    // inside the name starts a word of its own.
    if ([name hasPrefix:@"SGAppIcon"]) name = [name substringFromIndex:9];
    name = [name stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    NSMutableString *spaced = [NSMutableString string];
    for (NSUInteger i = 0; i < name.length; i++) {
        unichar c = [name characterAtIndex:i];
        if (i) {
            unichar previous = [name characterAtIndex:i - 1];
            BOOL upperAfterLower = c >= 'A' && c <= 'Z' && previous >= 'a' && previous <= 'z';
            BOOL digitAfterWord = c >= '0' && c <= '9' && ((previous >= 'A' && previous <= 'Z') || (previous >= 'a' && previous <= 'z'));
            BOOL wordAfterDigit = ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) && previous >= '0' && previous <= '9';
            if (upperAfterLower || digitAfterWord || wordAfterDigit) [spaced appendString:@" "];
        }
        [spaced appendFormat:@"%C", c];
    }
    return spaced;
}

// The icon's own picture, from the PNG the bundle carries: the 120pt one, or the 60pt one blown up.
static UIImage *preview(NSString *name) {
    name = nameOf(name);
    if (!name) {
        // The app's primary icon, which iOS keeps as its own key.
        NSDictionary *icons = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleIcons"];
        NSDictionary *primary = [icons isKindOfClass:NSDictionary.class] ? icons[@"CFBundlePrimaryIcon"] : nil;
        NSArray *files = [primary isKindOfClass:NSDictionary.class] ? primary[@"CFBundleIconFiles"] : nil;
        for (NSString *file in [files.reverseObjectEnumerator.allObjects copy] ?: @[]) {
            UIImage *image = [UIImage imageNamed:file];
            if (image) return image;
        }
        return [UIImage systemImageNamed:@"app.fill"];
    }
    for (NSString *suffix in @[@"120x120@2x", @"60x60@3x", @"60x60@2x"]) {
        UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"%@%@", name, suffix]];
        if (image) return image;
    }
    return [UIImage systemImageNamed:@"app.fill"];
}

static void setIcon(NSString *icon) {
    [UIApplication.sharedApplication setAlternateIconName:icon completionHandler:^(NSError *error) {
        if (!error) {
            // The strip repaints: iOS is the one that knows, and it has just changed.
            dispatch_async(dispatch_get_main_queue(), ^{
                [NSNotificationCenter.defaultCenter postNotificationName:@"spotifyglass.appIconDidChange" object:nil];
            });
            return;
        }
        SGLog(@"app icon: %@ not set: %@", label(icon), error.localizedDescription);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"The icon did not change"
                                                                           message:error.localizedDescription
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [SGTopController() presentViewController:alert animated:YES completion:nil];
        });
    }];
}

#pragma mark - the strip

@interface SGAppIconStripView : UIView
@property (nonatomic, copy) NSArray<NSString *> *names;   // first is nil's place, the app's own
@end

@implementation SGAppIconStripView {
    UIScrollView *_run;
    NSMutableArray<UIView *> *_cells;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (!(self = [super initWithFrame:frame])) return nil;
    self.backgroundColor = SGCardBackground();
    self.layer.cornerRadius = 16;    self.layer.cornerCurve = kCACornerCurveContinuous;
    _run = [UIScrollView new];
    _run.showsHorizontalScrollIndicator = NO;
    _run.alwaysBounceHorizontal = YES;
    [self addSubview:_run];
    _cells = [NSMutableArray array];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(repaint) name:@"spotifyglass.appIconDidChange" object:nil];
    return self;
}

- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (void)setNames:(NSArray<NSString *> *)names {
    _names = [names copy];
    for (UIView *cell in _cells) [cell removeFromSuperview];
    [_cells removeAllObjects];
    for (NSString *name in names) [_cells addObject:[self cellFor:name]];
    [self setNeedsLayout];
}

- (UIView *)cellFor:(NSString *)name {
    UIControl *cell = [UIControl new];
    cell.tag = [_names indexOfObject:name];
    [cell addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
    // NSNull stands for the app's own icon here; `label` and `preview` read it as nil.
    UIImageView *picture = [UIImageView new];
    picture.image = preview(name);
    picture.contentMode = UIViewContentModeScaleAspectFit;
    picture.layer.cornerRadius = 14;
    picture.layer.cornerCurve = kCACornerCurveContinuous;
    picture.clipsToBounds = YES;
    picture.tag = 1;
    [cell addSubview:picture];

    UILabel *title = [UILabel new];
    title.text = label(name);
    title.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    title.textColor = [UIColor colorWithWhite:1 alpha:0.6];
    title.textAlignment = NSTextAlignmentCenter;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    title.tag = 2;
    [cell addSubview:title];
    cell.accessibilityLabel = label(name);
    [_run addSubview:cell];
    return cell;
}

- (void)repaint {
    [self setNeedsLayout];
}

- (void)tapped:(UIControl *)cell {
    id name = _names[(NSUInteger)cell.tag];
    setIcon([name isKindOfClass:NSNull.class] ? nil : name);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat inset = 16, size = 60, labelHeight = 16, gap = 12;
    _run.frame = CGRectMake(0, inset, CGRectGetWidth(self.bounds), size + labelHeight + 4);
    CGFloat x = inset;
    for (UIView *cell in _cells) {
        cell.frame = CGRectMake(x, 0, size, size + labelHeight + 4);
        UIView *picture = [cell viewWithTag:1];
        picture.frame = CGRectMake(0, 0, size, size);
        UIView *title = [cell viewWithTag:2];
        title.frame = CGRectMake(-6, size + 4, size + 12, labelHeight);
        x += size + gap;
    }
    _run.contentSize = CGSizeMake(x + inset - gap, size + labelHeight + 4);
    // The chosen one is in the run with its ring drawn on the cell: the picture carries the corner, the cell the
    // ring, so the ring is not cut by the picture's own clipping.
    NSString *current = UIApplication.sharedApplication.alternateIconName;
    for (UIView *cell in _cells) {
        NSString *name = nameOf(_names[(NSUInteger)cell.tag]);
        BOOL on = current ? [name isEqualToString:current] : name == nil;
        cell.layer.cornerRadius = 18;
        cell.layer.borderWidth = on ? 2 : 0;
        cell.layer.borderColor = SGGreen().CGColor;
        UIView *picture = [cell viewWithTag:1];
        picture.frame = CGRectInset(picture.frame, on ? 4 : 0, on ? 4 : 0);
    }
    // As tall as the run is: the inset above it, the pictures, their names under them, and the inset below.
    self.frame = CGRectMake(self.frame.origin.x, self.frame.origin.y, self.frame.size.width, size + labelHeight + 4 + 2 * inset);
}

@end

UIView *SGAppIconStrip(void) {
    NSArray<NSString *> *names = iconNames();
    if (!UIApplication.sharedApplication.supportsAlternateIcons) return nil;
    SGAppIconStripView *strip = [[SGAppIconStripView alloc] initWithFrame:CGRectMake(0, 0, 320, 92)];
    strip.names = [@[NSNull.null] arrayByAddingObjectsFromArray:names];
    return strip;
}

// The page the All icons row opens, the way the newer build has one (SGAppIconPage): every alternate the IPA
// carries, four to a row, the one in effect ringed in the accent. A tap switches and rings where the finger is,
// it, without leaving the page; the strip on the Appearance page repaints with it, since both read iOS. A page of
// the mod's own goes through SGPage, which is what the navigation stack it is pushed onto takes.
@interface SGAppIconPickerPage : SGPage
@end

@implementation SGAppIconPickerPage {
    UIScrollView *_scroll;
    NSMutableArray<NSString *> *_names;   // NSNull for the app's own
    NSMutableArray<UIControl *> *_cells;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"App icons";
    _names = [NSMutableArray arrayWithObject:(NSString *)NSNull.null];
    [_names addObjectsFromArray:iconNames()];
    _cells = [NSMutableArray array];
    _scroll = [UIScrollView new];
    [self.view addSubview:_scroll];
    for (NSUInteger i = 0; i < _names.count; i++) {
        UIControl *cell = [UIControl new];
        cell.tag = (NSInteger)i;
        [cell addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        UIImageView *picture = [UIImageView new];
        picture.image = preview(_names[i]);
        picture.contentMode = UIViewContentModeScaleAspectFit;
        picture.layer.cornerRadius = 15;
        picture.layer.cornerCurve = kCACornerCurveContinuous;
        picture.clipsToBounds = YES;
        picture.tag = 1;
        picture.userInteractionEnabled = NO;
        [cell addSubview:picture];
        UILabel *title = [UILabel new];
        title.text = label(_names[i]);
        title.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
        title.textColor = [UIColor colorWithWhite:1 alpha:0.6];
        title.textAlignment = NSTextAlignmentCenter;
        title.lineBreakMode = NSLineBreakByTruncatingTail;
        title.tag = 2;
        title.userInteractionEnabled = NO;
        [cell addSubview:title];
        cell.accessibilityLabel = label(_names[i]);
        [_scroll addSubview:cell];
        [_cells addObject:cell];
    }
    [self paint];
}

- (void)paint {
    NSString *current = UIApplication.sharedApplication.alternateIconName;
    for (UIControl *cell in _cells) {
        NSString *name = nameOf(_names[(NSUInteger)cell.tag]);
        BOOL on = current ? [name isEqualToString:current] : name == nil;
        cell.layer.borderWidth = on ? 2 : 0;
        cell.layer.borderColor = SGGreen().CGColor;
        cell.layer.cornerRadius = 20;
    }
}

- (void)tapped:(UIControl *)cell {
    id name = _names[(NSUInteger)cell.tag];
    setIcon([name isKindOfClass:NSNull.class] ? nil : name);
    [self paint];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect bounds = self.view.bounds;
    CGFloat inset = 16, gap = 14, columns = 4;
    CGFloat cellWidth = floor((CGRectGetWidth(bounds) - 2 * inset - (columns - 1) * gap) / columns);
    CGFloat cellHeight = cellWidth + 22;
    _scroll.frame = bounds;
    _scroll.contentInset = UIEdgeInsetsMake(16, 0, 32, 0);
    CGFloat x = inset, y = 16;
    for (NSUInteger i = 0; i < _cells.count; i++) {
        UIControl *cell = _cells[i];
        cell.frame = CGRectMake(x, y, cellWidth, cellHeight);
        [cell viewWithTag:1].frame = CGRectMake(0, 0, cellWidth, cellWidth);
        [cell viewWithTag:2].frame = CGRectMake(-4, cellWidth + 4, cellWidth + 8, 16);
        x += cellWidth + gap;
        if ((i + 1) % (NSUInteger)columns == 0) { x = inset; y += cellHeight + gap; }
    }
    _scroll.contentSize = CGSizeMake(CGRectGetWidth(bounds), y + cellHeight + 16);
}

@end

SGModRow *SGAppIconCountRow(void) {
    NSArray<NSString *> *names = iconNames();
    if (!names.count || !UIApplication.sharedApplication.supportsAlternateIcons) return nil;
    SGModRow *row = SGPageRow(@"All icons", ^{ return (UIViewController *)[SGAppIconPickerPage new]; });
    row.value = ^NSString *{ return [@(names.count) stringValue]; };
    return row;
}
