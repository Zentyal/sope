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

#ifndef WOJsonCondition_H
#define WOJsonCondition_H 1

#include <NGObjWeb/WODynamicElement.h>

@interface WOJsonCondition : WODynamicElement
{
@protected
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString

  WOAssociation *condition;
  WOElement     *thenTemplate;
  WOElement     *elseTemplate;

  // non-WO
  WOAssociation *value; // compare the condition with value

#if DEBUG
  NSString *condName;
#endif
}

- (id)initWithName:(NSString *)_name
      associations:(NSDictionary *)_config
      thenTemplate:(WOElement *)_then
      elseTemplate:(WOElement *)_else;

@end /* WOJsonCondition */

#endif /* WOJsonCondition_H */
