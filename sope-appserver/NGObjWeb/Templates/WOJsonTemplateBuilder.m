/*
  Copyright (C) 2014 Zentyal

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "common.h"

#include <SBJson/SBJsonParser.h>


#include "Associations/WOValueAssociation.h"
#include "Associations/WOLabelAssociation.h"
#include "Associations/WOKeyPathAssociation.h"
#include "DynamicElements/WOComponentContent.h"
#include "DynamicElements/WOComponentReference.h"
#include "DynamicElements/WOCompoundElement.h"
#include "DynamicElements/WOJsonCondition.h"
#include "WOChildComponentReference.h"

#include "NGObjWeb/WOComponent.h"
#include "WOJsonTemplateBuilder.h"

/* TODO
   - loops (+ extra attributes)
   - extra attributes for strings
   - inputs: rest */

@interface JsonComponentIdGenerator : NSObject
{
    NSUInteger levels[4096];
    int nextLevel;
}

- (id) init;
- (void) pushLevel;
- (void) popLevel;

- (NSString *) getId;

@end


typedef WOElement * (*BuilderMethod)(WOJsonTemplateBuilder *,
                                     SEL,
                                     NSDictionary *,
                                     WOTemplate *,
                                     JsonComponentIdGenerator*);

@implementation JsonComponentIdGenerator

- (id) init
{
    if ((self = [super init])) {
        nextLevel = 0;
    }
    return self;
}

- (void) pushLevel
{
    if (nextLevel < sizeof(levels)) {
        levels[nextLevel] = 0;
        nextLevel++;
    }
}

- (void) popLevel
{
    if (nextLevel > 0) {
        nextLevel--;
    }
    else {
        [NSException raise: @"JSONException"
                     format: @"excessive level pop"];
    }
}

- (NSString *) getId
{
    NSUInteger lvl;
    NSMutableString *compId;

    if (nextLevel == 0) {
        [NSException raise: @"JSONException"
                     format: @"levels not pushed"];
    }
    compId = [NSMutableString stringWithCapacity: 64];
    for (lvl = 0; lvl < nextLevel; lvl++) {
        if (lvl > 0)
            [compId appendFormat: @".%u", levels[lvl]];
        else
            [compId appendFormat: @"%u", levels[lvl]];
    }
    levels[nextLevel-1]++;

    return compId;
}

@end


@implementation WOJsonTemplateBuilder

Class _WOString;
Class _WORepetition;

+ (void) initialize
{
  _WOString = NSClassFromString(@"WOString");
  _WORepetition = NSClassFromString(@"WORepetition");
}

- (Class) templateClass
{
  return [WOTemplate class];
}

- (WOAssociation *) associationFromValue: (NSDictionary *) value
{
    NSString *type, *valueStr;
    Class assocClass;

    valueStr = [value objectForKey: @"value"];
    type = [value objectForKey: @"type"];
    if ([type isEqualToString: @"const"])
        assocClass = [WOValueAssociation class];
    else if ([type isEqualToString: @"var"])
        assocClass = [WOKeyPathAssociation class];
    else if ([type isEqualToString: @"label"])
        assocClass = [WOLabelAssociation class];
    else {
        [NSException raise: @"JSONTemplateException"
                     format: @"unknown association type: %@", type];
        assocClass = Nil;
    }

    return [[assocClass alloc] initWithString: valueStr];
}

- (NSMutableDictionary *) genAssociations: (NSDictionary *) parameters
{
  NSMutableDictionary *assocParameters;
  NSArray *keys;
  NSUInteger i, max;
  NSString *key;
  WOAssociation *param;

  keys = [parameters allKeys];
  max = [keys count];
  assocParameters = [[NSMutableDictionary alloc]
                        initWithCapacity: max + 1];
  for (i = 0; i < max; i++) {
    key = [keys objectAtIndex: i];
    param = [self associationFromValue:
                      [parameters objectForKey: key]];
    if (param)
        [assocParameters setObject: param forKey: key];
    else
        [self errorWithFormat: @"malformed parameter in template: %@",
              [parameters objectForKey: key]];
    [param release];
  }

  return assocParameters;
}

- (WOElement *) buildElementFromString: (NSDictionary *) root
                            inTemplate: (WOTemplate *) template
                                 idGen: (JsonComponentIdGenerator *) idGen
{
    WOElement *result;
    NSMutableDictionary *assocParameters;
    NSString *componentId;

    // [self logWithFormat: @"buildElementFromString"];
    WOAssociation * assoc = [self associationFromValue: root];
    assocParameters = [[NSMutableDictionary alloc] initWithCapacity: 1];
    [assocParameters setObject: assoc forKey: @"value"];
    [assoc release];

    componentId = [idGen getId];
    // [self logWithFormat: @"string element has id %@", componentId];

    result = [[_WOString alloc] initWithName: componentId
                                associations: assocParameters
                                template: nil];
    [assocParameters release];

    return result;
}

- (WOElement *) buildElementFromInput: (NSDictionary *) root
                           inTemplate: (WOTemplate *) template
                                idGen: (JsonComponentIdGenerator *) idGen
{
    WODynamicElement *result;
    NSDictionary *element;
    NSMutableDictionary *mutableRoot;
    NSMutableDictionary *assocParameters, *extraParameters;
    NSString *componentId;
    NSString *type;
    NSUInteger i;
    static NSString *types[] = {@"text", @"file", @"image", @"radio",
                                @"reset", @"submit", @"hidden",
                                @"checkbox", @"password", @"textarea",
                                @"popup"};
    static NSString *typeClasses[] = {@"WOTextField", @"WOFileUpload",
                                      @"WOImageButton", @"WORadioButton",
                                      @"WOResetButton", @"WOSubmitButton",
                                      @"WOHiddenField", @"WOCheckBox",
                                      @"WOPasswordField", @"WOText",
                                      @"WOPopUpButton"};
    Class inputClass = Nil;

    type = [[root objectForKey: @"type"] objectForKey: @"value"];
    for (i = 0; i < (sizeof(types)/sizeof(NSString *)); i++) {
        if ([type isEqualToString: types[i]]) {
            inputClass = NSClassFromString(typeClasses[i]);
            if (!inputClass)
                [NSException raise: @"JSONError"
                            format: @"class '%@' for input type '%@' not"
                             @" found", typeClasses[i], type];
            break;
        }
    }
    if (!inputClass)
        [NSException raise: @"JSONError"
                     format: @"no class for input type '%@'", type];

    element = [root objectForKey: @"extra"];
    if (element)
        extraParameters = [self genAssociations: element];
    else
        extraParameters = nil;

    mutableRoot = [root mutableCopy];
    [mutableRoot removeObjectForKey: @"type"];
    [mutableRoot removeObjectForKey: @"extra"];

    assocParameters = [self genAssociations: mutableRoot];
    [mutableRoot release];

    componentId = [idGen getId];
    result = [[inputClass alloc] initWithName: componentId
                                 associations: assocParameters
                                 template: nil];
    [assocParameters release];
    if (extraParameters) {
        [result setExtraAttributes: extraParameters forJsonTemplate: YES];
        [extraParameters release];
    }

    return result;
}

- (WOElement *) buildElementFromCondition: (NSDictionary *) root
                               inTemplate: (WOTemplate *) template
                                    idGen: (JsonComponentIdGenerator *) idGen
{
    WOElement *result;
    WOElement *thenTemplate, *elseTemplate;
    NSString *componentId;
    NSDictionary *jsonValue;
    NSMutableDictionary *mutableRoot;
    NSMutableDictionary *assocParameters;

    // [self logWithFormat: @"entering buildElementFromCondition"];

    componentId = [idGen getId];
    // [self logWithFormat: @"condition element has id %@", componentId];

    mutableRoot = [root mutableCopy];
    [mutableRoot removeObjectForKey: @"then"];
    [mutableRoot removeObjectForKey: @"else"];
    assocParameters = [self genAssociations: mutableRoot];
    [mutableRoot release];

    [idGen pushLevel];

    jsonValue = [root objectForKey: @"then"];
    if (jsonValue) {
        thenTemplate = [self buildElementFromContainer: jsonValue
                             inTemplate: template
                             idGen: idGen];
    }
    else {
        thenTemplate = nil;
    }

    jsonValue = [root objectForKey: @"else"];
    if (jsonValue) {
        elseTemplate = [self buildElementFromContainer: jsonValue
                             inTemplate: template
                             idGen: idGen];
    }
    else {
        elseTemplate = nil;
    }

    [idGen popLevel];

    // [self logWithFormat: @"leaving buildElementFromCondition"];

    result = [[WOJsonCondition alloc] initWithName: componentId
                                      associations: assocParameters
                                      thenTemplate: thenTemplate
                                      elseTemplate: elseTemplate];
    [assocParameters release];
    [thenTemplate release];
    [elseTemplate release];

    return result;
}

- (WOElement *) buildElementFromLoop: (NSDictionary *) root
                          inTemplate: (WOTemplate *) template
                               idGen: (JsonComponentIdGenerator *) idGen
{
    WODynamicElement *result;
    WOElement *componentContents;
    NSDictionary *element;
    NSMutableDictionary *assocParameters, *extraParameters, *mutableRoot;
    NSString *componentId;

    componentId = [idGen getId];
    mutableRoot = [root mutableCopy];


    element = [root objectForKey: @"extra"];
    if (element) {
        [mutableRoot removeObjectForKey: @"extra"];
        extraParameters = [self genAssociations: element];
    }
    else
        extraParameters = nil;

    element = [root objectForKey: @"contents"];
    if (element) {
        [mutableRoot removeObjectForKey: @"contents"];
        [idGen pushLevel];
        componentContents = [self buildElementFromContainer: element
                                  inTemplate: template
                                  idGen: idGen];
        [idGen popLevel];
    }
    else {
        componentContents = nil;
    }

    assocParameters = [self genAssociations: mutableRoot];
    [mutableRoot release];

    result = [[_WORepetition alloc]
                 initWithName: componentId
                 associations: assocParameters
                 template: componentContents];
    [assocParameters release];
    if (extraParameters) {
        [result setExtraAttributes: extraParameters forJsonTemplate: YES];
        [extraParameters release];
    }
    [componentContents release];

    return result;
}

- (WOElement *) buildElementFromContainer: (NSDictionary *) root
                               inTemplate: (WOTemplate *) template
                                    idGen: (JsonComponentIdGenerator *) idGen
{
    WOElement *result, *childElement;
    NSMutableArray *children;
    NSArray *jsonChildren;
    NSDictionary *jsonValue;
    NSUInteger i, j, max;

    // [self logWithFormat: @"entering buildElementFromContainer"];

    children = [NSMutableArray new];

    static NSString *keys[] = {@"strings", @"inputs", @"components", @"loops",
                               @"conditions"};
    static SEL selectors[]
        = {@selector(buildElementFromString:inTemplate:idGen:),
           @selector(buildElementFromInput:inTemplate:idGen:),
           @selector(buildElementFromComponent:inTemplate:idGen:),
           @selector(buildElementFromLoop:inTemplate:idGen:),
           @selector(buildElementFromCondition:inTemplate:idGen:)};
    static BuilderMethod *methods = NULL;

    if (!methods) {
        methods = malloc(sizeof(BuilderMethod *) * 5);
        for (i = 0; i < 5; i++) {
            SEL currentSel = selectors[i];
            methods[i]
                = (BuilderMethod) [WOJsonTemplateBuilder
                                      instanceMethodForSelector: currentSel];
        }
    }

    [idGen pushLevel];

    for (i = 0; i < 5; i++) {
        NSString *key = keys[i];
        jsonChildren = [root objectForKey: key];
        max = [jsonChildren count];

        for (j = 0; j < max; j++) {
            jsonValue = [jsonChildren objectAtIndex: j];

            BuilderMethod method = methods[i];
            childElement = method(self, selectors[i],
                                  jsonValue, template, idGen);
            if (childElement) {
                [children addObject: childElement];
                [childElement release];
            }
        }
    }

    if ([[root objectForKey: @"show-component-content"] boolValue]) {
        NSString *subId = [idGen getId];
        // [self logWithFormat: @"container element has component content id %@",
        //       subId];
        childElement = [[WOComponentContent alloc]
                           initWithName: subId
                           associations: nil
                           template: nil];
        [children addObject: childElement];
        [childElement release];
    }

    [idGen popLevel];

    // [self logWithFormat: @"container element %@ has %u children",
    //       componentId, [children count]];
    // [self logWithFormat: @"leaving buildElementFromContainer"];
    result = [[WOCompoundElement alloc]
                 initWithContentElements: children];
    [children release];

    return result;
}

- (WOElement *) buildElementFromComponent: (NSDictionary *) root
                               inTemplate: (WOTemplate *) template
                                    idGen: (JsonComponentIdGenerator *) idGen
{
    WOElement *result, *componentContents;
    NSDictionary *parameters;
    NSMutableDictionary *assocParameters;
    NSDictionary *element;
    Class elementClass;
    NSString *componentId;
    BOOL isConstant;
    WOAssociation *componentClass;

    componentId = [idGen getId];
    // [self logWithFormat: @"entering buildElementFromComponent"];

    // [self logWithFormat: @"component element has id %@", componentId];

    /* component class */
    element = [root objectForKey: @"class-name"];
    if (element) {
        componentClass = [self associationFromValue: element];
        isConstant = [componentClass isValueConstant];
        if (isConstant)
            elementClass = [WOChildComponentReference class];
        else
            elementClass = [WOComponentReference class];
    }
    else {
        [NSException raise: @"JSONException"
                     format: @"no 'class-name' element"
                     " for component"];
        elementClass = Nil;
        componentClass = nil;
        isConstant = NO;
    }

    /* converting parameters into associations */
    parameters = [root objectForKey: @"parameters"];
    assocParameters = [self genAssociations: parameters];

    if (isConstant) {
        [template addSubcomponentWithKey: componentId
                  name: [element objectForKey: @"value"]
                  bindings: assocParameters];
    }
    else {
        [assocParameters setObject: componentClass forKey: @"component"];
    }
    [componentClass release];

    element = [root objectForKey: @"contents"];
    if (element) {
        [idGen pushLevel];
        componentContents = [self buildElementFromContainer: element
                                  inTemplate: template
                                  idGen: idGen];
        [idGen popLevel];
    }
    else {
        componentContents = nil;
    }

    // [self logWithFormat: @"leaving buildElementFromComponent"];

    result = [[elementClass alloc]
                 initWithName: componentId
                 associations: assocParameters
                 template: componentContents];
    [assocParameters release];
    [componentContents release];

    return result;
}

- (WOTemplate *)buildTemplateAtURL:(NSURL *)_url {
  NSAutoreleasePool *pool;
  WOTemplate        *template;
  SBJsonParser      *parser;
  NSStringEncoding usedEncoding;
  NSError *error;
  NSString *contents;

//   [self logWithFormat:@"loading JSON template %@ ...", [_url absoluteString]];

  pool = [[NSAutoreleasePool alloc] init];

  parser = [SBJsonParser new];
  [parser autorelease];

  error = nil;
  contents = [NSString stringWithContentsOfURL: _url
                       usedEncoding: &usedEncoding
                       error: &error];
  NSDictionary *root = [parser objectWithString: contents];
  WOElement *rootElement;

  JsonComponentIdGenerator *idGen = [JsonComponentIdGenerator new];
  [idGen autorelease];

  template = [[self templateClass] alloc];
  [template initWithURL: _url rootElement: nil];

  [idGen pushLevel];
  if ([root objectForKey: @"class-name"])
      rootElement = [self buildElementFromComponent: root
                          inTemplate: template
                          idGen: idGen];
  else
      rootElement = [self buildElementFromContainer: root
                          inTemplate: template
                          idGen: idGen];
  [idGen popLevel];
  [template setRootElement: rootElement];
  [rootElement release];

  [pool release];

  return template;
}

@end /* WOxTemplateBuilder */
