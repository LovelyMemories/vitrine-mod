#import "SGFColor.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"

// Flow's own accent, 0xRRGGBB, unset by default; the redesign's is its own key and its own color.
static NSString *const kFlowAccentKey = @"spotifyglass.flow.accent";

// The artwork averaged to one pixel: the cover's color as the eye gets it from across the room, which is
// what a wash should be. A cover with a white wall behind a pink subject reads gray here, and the glow
// then takes the accent -- the same case Follow the cover handles in the redesign.
static UIColor *averageColor(UIImage *image) {
    CGImageRef cg = image.CGImage;
    if (!cg) return nil;
    unsigned char pixel[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return nil;
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), cg);
    CGContextRelease(context);
    return [UIColor colorWithRed:pixel[0] / 255.0 green:pixel[1] / 255.0 blue:pixel[2] / 255.0 alpha:1];
}

UIColor *SGFBlack(void) {
    return [UIColor colorWithRed:0x09 / 255.0 green:0x09 / 255.0 blue:0x0B / 255.0 alpha:1];
}

UIColor *SGFAccent(void) {
    NSInteger rgb = SGInt(kFlowAccentKey, -1);
    if (rgb >= 0) {
        return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0 green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0 alpha:1];
    }
    return SGAccentMark();
}

// The cover's hue kept, its pull on the eye set to `saturation` and `brightness`; a color too gray to read
// as a color gives the accent back whole.
static UIColor *tinted(UIColor *average, CGFloat saturation, CGFloat brightness) {
    CGFloat h = 0, s = 0, b = 0, a = 1;
    if (!average || ![average getHue:&h saturation:&s brightness:&b alpha:&a] || s < 0.08) return SGFAccent();
    return [UIColor colorWithHue:h saturation:MIN(1, s * saturation) brightness:MIN(1, b * brightness) alpha:1];
}

UIColor *SGFWashForImage(UIImage *image) {
    return tinted(averageColor(image), 0.85, 0.42);
}

UIColor *SGFGlowForImage(UIImage *image) {
    // Bright enough to read over the wash and under white text, never a second white.
    return tinted(averageColor(image), 1.05, 0.95);
}
