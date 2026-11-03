#import "SGPageTitle.h"
#import "SGPageStyle.h"
#import "Core/SGCore.h"

static char kTitleKey, kCloseKey;

// A round button of the bar's own glass: the × on the trailing edge, 34pt across, as the screenshots have it.
static UIButton *closeButtonFor(UIViewController *page) {
    UIButton *button = objc_getAssociatedObject(page.navigationController, &kCloseKey);
    if (button) return button;
    button = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImageSymbolConfiguration *symbol = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
    [button setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:symbol] forState:UIControlStateNormal];
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = [UIColor colorWithWhite:1 alpha:0.12];
    button.layer.cornerRadius = 17;
    button.accessibilityLabel = @"Close";
    [button addTarget:page action:@selector(sg_closePushed) forControlEvents:UIControlEventTouchUpInside];
    objc_setAssociatedObject(page.navigationController, &kCloseKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return button;
}

@implementation UIViewController (SGPageTitleClose)

- (void)sg_closePushed {
    if (self.navigationController.presentingViewController && self.navigationController.viewControllers.count <= 1) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

@end

void SGPageShowLargeTitle(UIViewController *page) {
    if (!page || !page.isViewLoaded) return;
    UINavigationBar *bar = page.navigationController.navigationBar;
    if (!bar || objc_getAssociatedObject(page, &kTitleKey)) return;
    NSString *title = page.title ?: page.navigationItem.title;
    if (!title.length) return;

    UILabel *label = [UILabel new];
    label.text = title;
    label.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
    label.textColor = UIColor.whiteColor;
    label.accessibilityTraits = UIAccessibilityTraitHeader;
    UIView *holder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    [holder addSubview:label];
    label.frame = CGRectMake(-8, 2, 260, 40);
    page.navigationItem.titleView = holder;
    objc_setAssociatedObject(page, &kTitleKey, holder, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIButton *close = closeButtonFor(page);
    page.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:close];
    CGSize size = CGSizeMake(34, 34);
    if (CGSizeEqualToSize(close.bounds.size, size)) return;
    close.bounds = (CGRect){CGPointZero, size};
}
