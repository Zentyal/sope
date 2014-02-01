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

#include <NGObjWeb/WOxElemBuilder.h>
#include "decommon.h"
#include "WOElement+private.h"

#include "Associations/WOLabelAssociation.h"
#include "Associations/WOKeyPathAssociation.h"

#include "WOJsonResponse.h"
#include "WOJsonCondition.h"

@implementation WOJsonCondition

static int descriptiveIDs = -1;
static Class WOKeyPathAssociationK;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  descriptiveIDs = [ud boolForKey:@"WODescriptiveElementIDs"] ? 1 : 0;
  WOKeyPathAssociationK = [WOKeyPathAssociation class];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  thenTemplate:(WOElement *)_then
  elseTemplate:(WOElement *)_else
{
#if DEBUG
  self->condName = _name ? [_name copy] : (id)@"condYES";
#endif
  
  if ((self = [super initWithName:_name associations:_config template:nil])) {
    self->condition = OWGetProperty(_config, @"condition");
    self->value     = OWGetProperty(_config, @"value");
    self->thenTemplate  = [_then retain];
    self->elseTemplate  = [_else retain];
    
    if (self->condition == nil) {
      [self warnWithFormat:
              @"missing 'condition' association in element: '%@'", _name];
    }
  }
  return self;
}

- (void)dealloc {
  [self->elseTemplate  release];
  [self->thenTemplate  release];
  [self->value     release];
  [self->condition release];
#if DEBUG
  [self->condName release];
#endif
  [super dealloc];
}

/* state */

static WOElement * _template(WOJsonCondition *self, WOContext *_ctx) {
  WOComponent *cmp = [_ctx component];
  BOOL eval   = NO;

  if (self->value) {
    id v  = [self->value     valueInComponent:cmp];
    id cv = [self->condition valueInComponent:cmp];
    
    eval = [cv isEqual:v];
  }
  else
    eval = [self->condition boolValueInComponent:cmp];
  
  return (eval ? self->thenTemplate : self->elseTemplate);
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOElement *template = _template(self, _ctx);

#if DEBUG
  [_ctx appendElementIDComponent:
	  descriptiveIDs ? self->condName : (NSString *)@"1"];
#else
  [_ctx appendElementIDComponent:@"1"];
#endif
  [template takeValuesFromRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *state;
  NSString *key;
  id result;

  state = [[_ctx currentElementID] stringValue];
  
  if (!state) 
    return nil;
    
  [_ctx consumeElementID]; // consume state-id (on or off)
    
#if DEBUG
  key = descriptiveIDs ? self->condName : (NSString *)@"1";
#else
  key = @"1";
#endif
    
  if (![state isEqualToString:key])
    return nil;
      
  [_ctx appendElementIDComponent:state];
  WOElement *template = _template(self, _ctx);
  result = [template invokeActionForRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  return result;
}

/* generating response */

- (void)appendToJsonResponse:(WOJsonResponse *)_response
                   inContext:(WOContext *)_ctx {
  NSString *key;
  id v;
  WOComponent *cmp = [_ctx component];

#if DEBUG
  [_ctx appendElementIDComponent:
	  descriptiveIDs ? self->condName : (NSString *)@"1"];
#else
  [_ctx appendElementIDComponent:@"1"];
#endif

  if ([self->condition isKindOfClass: WOKeyPathAssociationK])
    key = [(WOKeyPathAssociation *) self->condition keyPath];
  else
    key = [self->condition value];

  if (self->value)
    v = [self->condition valueInComponent:cmp];
  else
    v = [NSNumber numberWithBool:
                      [self->condition boolValueInComponent:cmp]];
  [_response appendValueWithKey: key value: v];

  WOElement *template = _template(self, _ctx);
  [template appendToJsonResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  if (self->condition) [str appendFormat:@" condition=%@", self->condition];
  if (self->thenTemplate)  [str appendFormat:@" thenTemplate=%@",  self->thenTemplate];
  if (self->elseTemplate)  [str appendFormat:@" elseTemplate=%@",  self->elseTemplate];
  return str;
}

@end /* WOJsonCondition */
