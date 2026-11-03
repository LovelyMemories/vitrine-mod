#import "AutoMix.h"
#import <dlfcn.h>
#import <string.h>
#import "Core/SGCore.h"

// The helper's one export: C strings in, a C string out. Its Swift declaration is
//   @_cdecl("SGAutoMixPlan") func SGAutoMixPlan(_ a: UnsafePointer<Int8>?, _ b: UnsafePointer<Int8>?,
//                                              _ c: UnsafePointer<Int8>?) -> UnsafeMutablePointer<Int8>?
typedef char *(*SGAutoMixPlanFn)(const char *, const char *, const char *);

static void *sg_helper;
static SGAutoMixPlanFn sg_plan;
static BOOL sg_loaded;
static BOOL sg_available;

// Beside the tweak, in the app's Frameworks: the same place the build puts it (tweak/AutoMix/README.md).
static void *openHelper(void) {
    NSString *name = @"SpotifyGlassAutoMix.dylib";
    if (@available(iOS 26.0, *)) name = @"SpotifyGlassAutoMix26.dylib";
    NSString *path = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:name];
    void *handle = dlopen(path.fileSystemRepresentation, RTLD_NOW);
    if (!handle) {
        // The base helper beside it: a system whose SonicKit is the older layout but whose version reads newer.
        NSString *fallback = @"SpotifyGlassAutoMix.dylib";
        if (![name isEqualToString:fallback]) {
            path = [NSBundle.mainBundle.privateFrameworksPath stringByAppendingPathComponent:fallback];
            handle = dlopen(path.fileSystemRepresentation, RTLD_NOW);
        }
    }
    if (!handle) {
        SGLog(@"automix: no planner (%s)", dlerror() ?: "dlopen failed");
        return NULL;
    }
    return handle;
}

static void load(void) {
    if (sg_loaded) return;
    sg_loaded = YES;
    sg_helper = openHelper();
    if (!sg_helper) return;
    // Read through a void * so the object-to-function-pointer conversion stays out of the compiler's way.
    *(void **)(&sg_plan) = dlsym(sg_helper, "SGAutoMixPlan");
    if (!sg_plan) {
        // Said the way the build 1.0.1 says it, so a log from either reads the same.
        SGLog(@"automix: no SGAutoMixPlan in the planner helper");
        return;
    }
    sg_available = YES;
    SGLog(@"automix: the planner is in");
}

BOOL SGAutoMixAvailable(void) {
    load();
    return sg_available;
}

static const char *jsonOf(NSDictionary *dictionary) {
    if (!dictionary) return "{}";
    NSData *data = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:NULL];
    if (!data) return "{}";
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    // Copied into a strdup the caller frees, since the string's own storage ends with this frame.
    return strdup(text.UTF8String ?: "{}");
}

NSString *SGAutoMixPlanForSongs(NSDictionary *outgoing, NSDictionary *incoming, NSDictionary *criteria) {
    if (!SGAutoMixAvailable()) return nil;
    const char *from = jsonOf(outgoing), *to = jsonOf(incoming), *ask = jsonOf(criteria);
    char *answer = sg_plan(from, to, ask);
    free((void *)from);
    free((void *)to);
    free((void *)ask);
    if (!answer) return nil;
    NSString *text = [NSString stringWithUTF8String:answer];
    free(answer);
    return text;
}

NSDictionary<NSString *, NSString *> *SGAutoMixCuePoints(NSString *uri, double duration,
                                                         double fadeOutStart, double fadeInEnd) {
    if (!uri.length || !(duration > 0)) return @{};
    fadeOutStart = fmax(0, fmin(fadeOutStart, duration));
    fadeInEnd = fmax(0, fmin(fadeInEnd, duration));
    return @{
        @"automix.fade_out_cuepoint.position": [NSString stringWithFormat:@"%.3f", fadeOutStart],
        @"automix.fade_out_cuepoint.origin": [NSString stringWithFormat:@"%.3f", duration],
        @"automix.fade_out_cuepoint.tempo": @"1",
        @"automix.fade_in_cuepoint.position": [NSString stringWithFormat:@"%.3f", fadeInEnd],
        @"automix.fade_in_cuepoint.origin": @"0",
        @"automix.fade_in_cuepoint.tempo": @"1",
        // A recipe of its own, so the two cue points read as one transition rather than as two stray numbers.
        @"automix.auto_transition_recipe": @"vitrine",
        @"automix.playable_uri": uri,
    };
}
