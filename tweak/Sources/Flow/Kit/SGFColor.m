#import "SGFColor.h"
#import "Core/SGCore.h"
#import "Settings/SGPageStyle.h"

// Flow's own accent, 0xRRGGBB, unset by default; the redesign's is its own key and its own color.
static NSString *const kFlowAccentKey = @"spotifyglass.flow.accent";

// The cover's color as the eye picks it: the most saturated of a grid of samples, not the average. An
// average turns a bright sky, a white wall or a glow into gray, which is exactly what an artwork's best
// color is not; the grid finds the one patch that is a color at all.
static UIColor *dominantColor(UIImage *image) {
    CGImageRef cg = image.CGImage;
    if (!cg) return nil;
    enum { kSide = 16 };
    unsigned char pixels[kSide * kSide * 4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, kSide, kSide, 8, kSide * 4, space,
                                                 kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return nil;
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    CGContextDrawImage(context, CGRectMake(0, 0, kSide, kSide), cg);
    CGContextRelease(context);

    CGFloat best = -1;
    UIColor *picked = nil;
    for (int i = 0; i < kSide * kSide; i++) {
        UIColor *color = [UIColor colorWithRed:pixels[i * 4] / 255.0 green:pixels[i * 4 + 1] / 255.0
                                         blue:pixels[i * 4 + 2] / 255.0 alpha:1];
        CGFloat h = 0, s = 0, v = 0, a = 1;
        if (![color getHue:&h saturation:&s brightness:&v alpha:&a]) continue;
        // Saturation first: a bright white patch is worth less than a dim colored one, a black one nothing.
        CGFloat score = s * 0.75 + v * 0.25;
        if (score > best) {
            best = score;
            picked = color;
        }
    }
    return picked;
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
static UIColor *tinted(UIColor *color, CGFloat saturation, CGFloat brightness) {
    CGFloat h = 0, s = 0, b = 0, a = 1;
    if (!color || ![color getHue:&h saturation:&s brightness:&b alpha:&a] || s < 0.06) return SGFAccent();
    return [UIColor colorWithHue:h saturation:MIN(1, s * saturation) brightness:MIN(1, b * brightness) alpha:1];
}

UIColor *SGFWashForImage(UIImage *image) {
    return tinted(dominantColor(image), 1.15, 0.52);
}

UIColor *SGFGlowForImage(UIImage *image) {
    // Bright enough to read over the wash and under white text, never a second white.
    return tinted(dominantColor(image), 1.05, 0.95);
}
