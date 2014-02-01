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


#import <Foundation/NSString.h>

#import "NGObjWeb/WOResponse.h"
#import "SoObjects/WOContext+SoObjects.h"
#import "WOContext+private.h"
#import "WOJsonResponse.h"

#import "SoJsonRenderer.h"


@implementation SoJsonRenderer

+ (id)sharedRenderer
{
    static SoJsonRenderer * renderer = nil;

    if (!renderer) {
        renderer = [self new];
    }

    return renderer;
}

- (NSException *) renderComponent: (id) _c
                        inContext: (WOContext *) _ctx
{
    WOJsonResponse *jsonResponse;

    jsonResponse = [WOJsonResponse new];

    [_ctx setPage:_c];
    [_ctx enterComponent:_c content:nil];
    [_c appendToJsonResponse: jsonResponse inContext:_ctx];
    [_ctx leaveComponent:_c];

    WOResponse *r = [_ctx response];

    [r setHeader:@"application/json; charset=utf-8" forKey:@"content-type"];
    [r appendContentData: [jsonResponse responseData]];

    [jsonResponse release];

    return nil;
}

@end
