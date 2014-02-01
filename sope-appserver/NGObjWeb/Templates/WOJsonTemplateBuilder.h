#import <NGObjWeb/WOTemplateBuilder.h>

@class NSDictionary;
@class WOTemplate;
@class JsonComponentIdGenerator;

@interface WOJsonTemplateBuilder : WOTemplateBuilder

- (WOElement *) buildElementFromString: (NSDictionary *) root
                            inTemplate: (WOTemplate *) template
                                 idGen: (JsonComponentIdGenerator *) idGen;
- (WOElement *) buildElementFromInput: (NSDictionary *) root
                           inTemplate: (WOTemplate *) template
                                idGen: (JsonComponentIdGenerator *) idGen;
- (WOElement *) buildElementFromCondition: (NSDictionary *) root
                               inTemplate: (WOTemplate *) template
                                    idGen: (JsonComponentIdGenerator *) idGen;
- (WOElement *) buildElementFromLoop: (NSDictionary *) root
                          inTemplate: (WOTemplate *) template
                               idGen: (JsonComponentIdGenerator *) idGen;
- (WOElement *) buildElementFromContainer: (NSDictionary *) root
                               inTemplate: (WOTemplate *) template
                                    idGen: (JsonComponentIdGenerator *) idGen;
- (WOElement *) buildElementFromComponent: (NSDictionary *) root
                               inTemplate: (WOTemplate *) template
                                    idGen: (JsonComponentIdGenerator *) idGen;

@end
