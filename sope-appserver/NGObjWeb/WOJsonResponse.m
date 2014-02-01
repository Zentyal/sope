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


#include <SBJson/SBJsonWriter.h>
#include "NGExtensions/NSObject+Logs.h"

#include "WOJsonResponse.h"


@implementation WOJsonResponse

Class NSStringK;

+ (void) initialize
{
  NSStringK = [NSString class];
}

- (id) init
{
  if ((self = [super init])) {
    inputs = [NSMutableArray new];
    labels = [NSMutableDictionary new];
    loops = [NSMutableDictionary new];
    strings = [NSMutableArray new];
    values = [NSMutableDictionary new];
  }

  return self;
}

- (void) dealloc
{
  [values release];
  [strings release];
  [loops release];
  [labels release];
  [inputs release];
  [super dealloc];
}

- (void) appendString: (NSString *) key;
{
  [strings addObject: key];
}

- (void) appendValueWithKey: (NSString *) key
                      value: (id) value;
{
  if (![key isKindOfClass: NSStringK])
    [NSException raise: @"JSONException"
                 format: @"appending a non-string key"];
  [values setObject: value forKey: key];
}

- (void) appendLabelWithKey: (NSString *) key
                      value: (NSString *) value;
{
  if (![key isKindOfClass: NSStringK])
    [NSException raise: @"JSONException"
                 format: @"appending a non-string key"];
  [labels setObject: value forKey: key];
}

- (void) appendInput: (NSDictionary *) attrs
{
  [inputs addObject: attrs];
}

- (void) appendLoopWithKey: (NSString *) key
           andSubResponses: (NSArray *) subResponses
{
  [loops setObject: subResponses forKey: key];
}

- (NSDictionary *) responseDictionary
{
  NSDictionary *subResp;
  NSMutableDictionary *responseDict, *respLoops;
  NSUInteger i, j, max, maxSubs;
  NSArray *loopKeys, *subResps;
  NSMutableArray *subDicts;
  NSString *key;

  responseDict = [NSMutableDictionary new];

  if ([strings count] > 0) {
      [responseDict setObject: strings forKey: @"strings"];
  }
  if ([values count] > 0) {
      [responseDict setObject: values forKey: @"values"];
  }
  if ([labels count] > 0) {
      [responseDict setObject: labels forKey: @"labels"];
  }
  if ([inputs count] > 0) {
      [responseDict setObject: inputs forKey: @"inputs"];
  }

  loopKeys = [loops allKeys];
  max = [loopKeys count];
  if (max > 0) {
    respLoops = [NSMutableDictionary new];
    [responseDict setObject: respLoops forKey: @"loops"];
    [respLoops release];

    for (i = 0; i < max; i++) {
      key = [loopKeys objectAtIndex: i];
      subResps = [loops objectForKey: key];
      maxSubs = [subResps count];
      subDicts = [NSMutableArray new];
      for (j = 0; j < maxSubs; j++) {
        subResp = [[subResps objectAtIndex: j] responseDictionary];
        [subDicts addObject: subResp];
        [subResp release];
      }
      [respLoops setObject: subDicts forKey: key];
      [subDicts release];
    }
  }

  return responseDict;
}

- (NSData *) responseData
{
  NSData *responseData;
  NSDictionary *responseDict;
  NSError *jsonError;
  NSString *responseStr;
  SBJsonWriter *writer;

  writer = [SBJsonWriter new];

  responseDict = [self responseDictionary];
  responseStr = [writer stringWithObject: responseDict error: &jsonError];
  if (responseStr)
    responseData = [responseStr dataUsingEncoding: NSUTF8StringEncoding];
  else {
    [self errorWithFormat: @"error serializing response: %@", jsonError];
    [NSException raise: @"JSONException"
                 format: @"error during the making of the response"];
  }
  [responseDict release];
  [writer release];

  return responseData;
}

@end
