#import "SGCanvas.h"

@implementation SGCanvas
@end

static SGCanvas *canvasWith(NSString *identifier, NSString *address, BOOL video) {
    if (!address.length) return nil;
    SGCanvas *canvas = [SGCanvas new];
    canvas.identifier = identifier.length ? identifier : @(address.hash).stringValue;
    canvas.address = address;
    canvas.video = video;
    return canvas;
}

SGCanvas *SGCanvasFromMetadata(NSDictionary *metadata) {
    if (![metadata isKindOfClass:NSDictionary.class]) return nil;
    NSString *address = metadata[@"canvas.url"];
    if (![address isKindOfClass:NSString.class]) return nil;
    NSString *type = [metadata[@"canvas.type"] isKindOfClass:NSString.class] ? metadata[@"canvas.type"] : nil;
    NSString *identifier = metadata[@"canvas.id"] ?: metadata[@"canvas.fileId"];
    return canvasWith([identifier isKindOfClass:NSString.class] ? identifier : nil, address,
                      [type hasPrefix:@"VIDEO"]);
}
