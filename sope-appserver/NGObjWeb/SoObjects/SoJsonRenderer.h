#import <NGObjWeb/SoDefaultRenderer.h>

@interface SoJsonRenderer : SoDefaultRenderer

+ (id)sharedRenderer;

- (NSException *) renderComponent: (id) _object
                        inContext: (WOContext *) _ctx;

@end
