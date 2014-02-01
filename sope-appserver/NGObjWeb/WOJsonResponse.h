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

#ifndef WOJsonResponse_H
#define WOJsonResponse_H

#import <Foundation/NSDictionary.h>

@class NSMutableArray;
@class NSMutableDictionary;

@interface WOJsonResponse : NSObject
{
  NSMutableArray *inputs;
  NSMutableDictionary *labels;
  NSMutableDictionary *loops;
  NSMutableArray *strings;
  NSMutableDictionary *values;
}

- (id) init;
- (void) dealloc;

- (void) appendString: (NSString *) key;
- (void) appendValueWithKey: (NSString *) key
                      value: (id) value;
- (void) appendLabelWithKey: (NSString *) key
                      value: (NSString *) value;
- (void) appendInput: (NSDictionary *) attributes;
- (void) appendLoopWithKey: (NSString *) key
           andSubResponses: (NSArray *) subResponses;

- (NSData *) responseData;

@end

#endif /* WOJsonResponse_H */
