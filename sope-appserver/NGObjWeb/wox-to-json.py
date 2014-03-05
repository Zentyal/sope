#!/usr/bin/python
#
# This file is part of SOPE.
#
# Copyright (C) 2014 Zentyal
#
# Author: Wolfgang Sourdeau <Wolfgang@Contre.COM>
#
# SOPE is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation; either version 2, or (at your option) any
# later version.
#
# SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with SOPE; see the file COPYING.  If not, write to the
# Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA.

# This script is used to translate .wox templates into equivalent .json
# templates

import json
import sys
import traceback

from xmllib import XMLParser

XHTML_NS = "http://www.w3.org/1999/xhtml"
XHTML_NS_LEN = len(XHTML_NS)
VAR_NS = "http://www.skyrix.com/od/binding"
VAR_NS_LEN = len(VAR_NS)
CONST_NS = "http://www.skyrix.com/od/constant"
CONST_NS_LEN = len(CONST_NS)
LABEL_NS = "OGo:label"
LABEL_NS_LEN = len(LABEL_NS)

# TODO: support for select

class JsonObject(object):
    def json_data(self):
        raise Exception("not implemented (%s)" % self.__class__)

    @classmethod
    def make_value(cls, k, value):
        if k.startswith(CONST_NS):
            val_type = JsonValue.CONST
            key = k[CONST_NS_LEN+1:]
        elif k.startswith(VAR_NS):
            val_type = JsonValue.VAR
            key = k[VAR_NS_LEN+1:]
        elif k.startswith(LABEL_NS):
            val_type = JsonValue.LABEL
            key = k[LABEL_NS_LEN+1:]
        else:
            key = k
            val_type = cls.default_key_type(key)

        return (key, JsonValue(value, val_type))

    def to_json(self, pretty=False):
        data = self.json_data()
        if pretty:
            return json.dumps(data,
                              indent=4,
                              separators=(',', ': '))
        else:
            return json.dumps(data)

class JsonValue(JsonObject):
    NONE = 0
    CONST = 1
    VAR = 2
    LABEL = 3
    MAX = 4
    LABELS = ("none", "const", "var", "label", "max")

    def __init__(self, value=None, val_type=None):
        if val_type == self.NONE or val_type >= self.MAX:
            raise Exception("invalid value type")
        self.type = val_type
        self.value = value

    def json_data(self):
        return {"type": self.LABELS[self.type], "value": self.value}

    def __repr__(self):
        return str(self.json_data())


class JsonString(JsonObject):
    @classmethod
    def default_key_type(self, key):
        if key in {"escapeHTML"}:
            return JsonValue.CONST
        else:
            return JsonValue.VAR

    def __init__(self, doc=""):
        self.value = None
        self.extra = {}

    def from_attrs(self, attrs):
        for k in attrs:
            (key, value) = self.make_value(k, attrs[k])

            if key == "value":
                self.value = value
            else:
                self.extra[key] = value

    def json_data(self):
        data = self.value.json_data()
        if len(self.extra) > 0:
            extra = {}
            for x in self.extra:
                extra[x] = self.extra[x].json_data()
            data["extra"] = extra

        return data


class JsonInput(JsonObject):
    ignored = {"class", "style", "size", "onchange", "onfocus", "tabindex"}

    @classmethod
    def default_key_type(cls, key):
        if (key in {"autocomplete", "name", "type", "id", "value", "rows",
                    "menuid", "multiple", "placeholder", "readonly"}
            or key in cls.ignored):
            return JsonValue.CONST
        raise Exception("unknown key: " + key)

    def __init__(self, doc=""):
        self.name = None
        self.type = None
        self.value = None
        self.extra = {}
        self.disabled = None

    def from_attrs(self, attrs):
        for k in attrs:
            (key, value) = self.make_value(k, attrs[k])

            if key == "name":
                self.name = value
            elif key in ("value", "checked"):
                self.value = value
            elif key == "disabled":
                self.disabled = value
            elif key == "type":
                self.type = value
            elif key not in self.ignored:
                self.extra[key] = value

    def json_data(self):
        data = {}
        if self.name is None:
            if self.value is None:
                return None
        else:
            data["name"] = self.name.json_data()
        if self.type is None:
            raise Exception("no type for input")
        else:
            data["type"] = self.type.json_data()
        if self.value is not None:
            data["value"] = self.value.json_data()
        if self.disabled is not None:
            data["disabled"] = self.disabled.json_data()
        if len(self.extra) > 0:
            extra = {}
            for x in self.extra:
                extra[x] = self.extra[x].json_data()
            data["extra"] = extra

        return data

class JsonPopup(JsonObject):
    @classmethod
    def default_key_type(cls, key):
        if key in {"list", "item", "string", "selection", "value"}:
            return JsonValue.VAR
        elif key in {"name"}:
            return JsonValue.CONST
        raise Exception("unknown key: " + key)

    def __init__(self, doc=""):
        self.type = JsonValue("popup", JsonValue.CONST)
        self.name = None
        self.value = None
        self.disabled = None
        self.list = None
        self.item = None
        self.item_string = None
        self.selection = None
        self.display_string = None
        self.no_selection_string = None
        self.selected_value = None
        self.escape_html = None
        self.item_group = None
        self.extra = {}

    def from_attrs(self, attrs):
        for k in attrs:
            (key, value) = self.make_value(k, attrs[k])

            if key == "name":
                self.name = value
            elif key in "value":
                self.value = value
            elif key in "disabled":
                self.disabled = value
            elif key == "list":
                self.list = value
            elif key == "item":
                self.item = value
            elif key == "string":
                self.item_string = value
            elif key == "selection":
                self.selection = value
            elif key == "displayString":
                self.display_string = value
            elif key == "noSelectionString":
                self.no_selection_string = value
            elif key == "selectedValue":
                self.selected_value = value
            elif key == "escapeHTML":
                self.escape_html = value
            elif key == "itemGroup":
                self.item_group = value
            else:
                self.extra[key] = value

    def json_data(self):
        data = {"type": self.type.json_data()}

        if self.name is not None:
            data["name"] = self.name.json_data()
        if self.value is not None:
            data["value"] = self.value.json_data()
        if self.disabled is not None:
            data["disabled"] = self.disabled.json_data()
        if self.list is not None:
            data["list"] = self.list.json_data()
        if self.item is not None:
            data["item"] = self.item.json_data()
        if self.item_string is not None:
            data["string"] = self.item_string.json_data()
        if self.selection is not None:
            data["selection"] = self.selection.json_data()
        if self.display_string is not None:
            data["displayString"] = self.display_string.json_data()
        if self.no_selection_string is not None:
            data["noSelectionString"] = self.no_selection_string.json_data()
        if self.selected_value is not None:
            data["selectedValue"] = self.selected_value.json_data()
        if self.escape_html is not None:
            data["escapeHTML"] = self.escape_html.json_data()
        if self.item_group is not None:
            data["itemGroup"] = self.item_group.json_data()
        if len(self.extra) > 0:
            extra = {}
            for x in self.extra:
                extra[x] = self.extra[x].json_data()
            data["extra"] = extra

        return data

class JsonTextArea(JsonInput):
    ignored = {"rows"}.union(JsonInput.ignored)

    def __init__(self):
        JsonInput.__init__(self)
        self.type = JsonValue("textarea", JsonValue.CONST)

# any element that has subelements
class _JsonContainer(JsonObject):
    def __init__(self):
        self.strings = []
        self.inputs = []
        self.components = []
        self.conditions = []
        self.loops = []
        self.show_content = False

    def merge_container(self, other):
        self.strings.extend(other.strings)
        self.inputs.extend(other.inputs)
        self.components.extend(other.components)
        self.conditions.extend(other.conditions)
        self.loops.extend(other.loops)
        self.show_content |= other.show_content

    def is_empty(self):
        return ((len(self.strings)
                + len(self.inputs)
                + len(self.components)
                + len(self.loops)
                + len(self.conditions))
                == 0
                and self.show_content is False)

    def json_data(self):
        data = {}

        keys = ("strings", "inputs", "components", "loops")
        cnt = 0
        for array in (self.strings, self.inputs, self.components, self.loops):
            if len(array) > 0:
                values = []
                for val in array:
                    json_data = val.json_data()
                    if json_data is not None:
                        values.append(json_data)
                if len(values) > 0:
                    data[keys[cnt]] = values
            cnt += 1

        json_conditions = {}
        for xml_condition in self.conditions:
            if not xml_condition.is_empty():
                cond_key = xml_condition.condition_key()
                if cond_key not in json_conditions:
                    ## print "new cond key: " + str(cond_key) + " in " + str(self)
                    json_conditions[cond_key] = JsonCondition()
                json_condition = json_conditions[cond_key]
                ## print "merging cond " + str(xml_condition) + " in " + str(self)
                json_condition.merge_xml_condition(xml_condition)
                ## print ">merged cond " + str(xml_condition) + " in " + str(self)
        if len(json_conditions) > 0:
            conditions = []
            for v in json_conditions.itervalues():
                conditions.append(v.json_data())
            data["conditions"] = conditions

        if self.show_content:
            data["show-component-content"] = True

        ## print ">end json_data in " + str(self)
        return data


# var:component tag
class JsonComponent(_JsonContainer):
    @classmethod
    def default_key_type(self, key):
        if key == "className":
            key_type = JsonValue.CONST
        else:
            key_type = JsonValue.VAR

        return key_type

    def __init__(self):
        _JsonContainer.__init__(self)
        self.class_name = None
        self.value = None
        self.parameters = {}

    def from_attrs(self, attrs):
        for k in attrs:
            (key, value) = self.make_value(k, attrs[k])

            if key == "className" or key == "value":
                if self.class_name is None:
                    self.class_name = value
                else:
                    raise Exception("class_name is already set")
            else:
                self.parameters[key] = value

    def json_data(self):
        data = {}
        if self.class_name is not None:
            data["class-name"] = self.class_name.json_data()
        if len(self.parameters) > 0:
            parameters = {}
            data["parameters"] = parameters
            for value in self.parameters:
                parameters[value] = self.parameters[value].json_data()
        if not self.is_empty():
            data["contents"] = _JsonContainer.json_data(self)

        return data


# var:if as XML representation
class JsonXMLCondition(_JsonContainer):
    ignored = {}

    @classmethod
    def default_key_type(self, key):
        if key == "condition":
            return JsonValue.VAR
        raise Exception("unknown key: " + key)

    def __init__(self):
        _JsonContainer.__init__(self)
        self.cond_value = None
        self.value = None
        self.negate = False

    def from_attrs(self, attrs):
        for k in attrs:
            (key, value) = self.make_value(k, attrs[k])
            if key == "condition":
                self.cond_value = value
            elif key == "negate":
                self.negate = value
            elif key == "value":
                self.value = value
            elif k not in self.ignored:
                raise Exception("unknown attr: " + k)

    def condition_key(self):
        cond_key = "%s/%s" % (JsonValue.LABELS[self.cond_value.type],
                              self.cond_value.value)
        if self.value is not None:
            cond_key += "==%s" % self.value.value
        return cond_key


# var:if as json representation
class JsonCondition(JsonObject):
    def __init__(self):
        JsonObject.__init__(self)
        self.test = None
        self.value = None
        self.then = None
        self.else_ = None

    def merge_xml_condition(self, xml_cond):
        self.test = xml_cond.cond_value
        self.value = xml_cond.value
        if xml_cond.negate:
            if self.else_ is None:
                self.else_ = xml_cond
            else:
                self.else_.merge_container(xml_cond)
        else:
            if self.then is None:
                self.then = xml_cond
            else:
                self.then.merge_container(xml_cond)

    def json_data(self):
        data = {"condition": self.test.json_data()}
        if self.value is not None:
            data["value"] = self.value.json_data()
        if self.then is not None:
            data["then"] = self.then.json_data()
        if self.else_ is not None:
            data["else"] = self.else_.json_data()

        ## print str(data)

        return data


# container tag
class JsonContainer(_JsonContainer):
    def __init__(self):
        _JsonContainer.__init__(self)

    def from_attrs(self, attrs):
        raise Exception("pouet")
        print "container attrs: " + str(attrs)


# var:if as json representation
class JsonLoop(_JsonContainer):
    ignored = {}

    @classmethod
    def default_key_type(self, key):
        if key in {"item", "list", "index"}:
            return JsonValue.VAR
        raise Exception("unknown key: " + key)

    def __init__(self):
        _JsonContainer.__init__(self)
        self.list = None
        self.item = None
        self.index = None
        self.contents = None
        self.identifier = None
        self.count = None
        self.start_index = None
        self.separator = None

        self.extra = {}

    def from_attrs(self, attrs):
        for k in attrs:
            (key, value) = self.make_value(k, attrs[k])

            if k == "list":
                self.list = value
            elif k == "item":
                self.item = value
            elif k == "index":
                self.index = value
            elif k == "identifier":
                self.identifier = value
            elif k == "count":
                self.count = value
            elif k == "startIndex":
                self.start_index = value
            elif k == "separator":
                self.separator = value
            else:
                self.extra[key] = value
        self.contents = _JsonContainer()

    def json_data(self):
        contents = _JsonContainer.json_data(self)
        if len(contents) > 0:
            data = {"contents": contents}
            if self.list is not None:
                data["list"] = self.list.json_data()
            if self.item is not None:
                data["item"] = self.item.json_data()
            if self.index is not None:
                data["index"] = self.index.json_data()
            if self.identifier is not None:
                data["identifier"] = self.identifier.json_data()
            if self.count is not None:
                data["count"] = self.count.json_data()
            if self.start_index is not None:
                data["startIndex"] = self.start_index.json_data()
            if self.separator is not None:
                data["separator"] = self.separator.json_data()
            if len(self.extra) > 0:
                extra = {}
                for x in self.extra:
                    extra[x] = self.extra[x].json_data()
                data["extra"] = extra
        else:
            data = None

        return data


class JsonPseudoContainer(_JsonContainer):
    def json_data(self):
        data = _JsonContainer.json_data(self)
        keys = data.keys()
        if ("components" in data
            and len(keys) == 1
            and len(data["components"]) == 1):
            data = data["components"][0]

        return data


# class representing HTML containers which have or not have a corresponding
# JSON container class
class ParserTag(object):
    def __init__(self, tag, json_container, parent_json_container):
        self.tag = tag
        self.json_container = json_container
        self.parent_json_container = parent_json_container


class Parser(XMLParser):
    ignored = {"head", "title", "meta", "link", "if-ie", "body",
               "iframe", "img", "noscript", "script", "div", "ul", "li",
               "form", "select", "option", "label", "a", "span", "br", "i",
               "p", "style", "table", "thead", "tbody", "td", "tr", "th",
               "entity", "fieldset", "legend", "pre", "strong", "small", "h1",
               "h3", "h4", "h5", "h6", "hr", "dl", "dt", "dd", "font",
               "button"}

    # list of container that will be taken into account only if they are the
    # topmost element of the xml tree
    pseudo_containers = {"html", "span", "div", "table"}

    def __init__(self, filename):
        XMLParser.__init__(self, accept_utf8=True)
        self.filename = filename
        self.parsed = False
        self.top_json_container = None
        self.current_json_container = None
        self.tag_stack = []

    def parse(self):
        inf = open(self.filename)
        contents = inf.read()
        start_idx = 0
        while ord(contents[start_idx]) > 127:
            start_idx += 1
        self.feed(contents[start_idx:])
        inf.close()
        self.close()
        self.parsed = True

    def _push_tag(self, tag, container):
        self.tag_stack.append(ParserTag(tag, container,
                                        self.current_json_container))
        if self.top_json_container is None:
            if container is None:
                raise Exception("top container should not be None")
            self.top_json_container = container
        if container is not None:
            self.current_json_container = container

    def handle_string(self, short_name, attrs):
        string = JsonString()
        string.from_attrs(attrs)
        self.current_json_container.strings.append(string)

    def handle_input(self, short_name, attrs, input_class):
        input_tag = input_class()
        input_tag.from_attrs(attrs)
        self.current_json_container.inputs.append(input_tag)

    def handle_loop(self, short_name, attrs):
        loop = JsonLoop()
        loop.from_attrs(attrs)
        if self.current_json_container is not None:
            self.current_json_container.loops.append(loop)
        self._push_tag(short_name, loop)

    def handle_if(self, short_name, attrs):
        condition = JsonXMLCondition()
        condition.from_attrs(attrs)
        if self.current_json_container is not None:
            self.current_json_container.conditions.append(condition)
        self._push_tag(short_name, condition)

    def handle_component(self, short_name, attrs):
        component = JsonComponent()
        component.from_attrs(attrs)
        if self.current_json_container is not None:
            self.current_json_container.components.append(component)
        self._push_tag(short_name, component)

    def handle_container(self, short_name, attrs):
        container = JsonContainer()
        if self.current_json_container is not None:
            self.current_json_container.containers.append(container)
        self._push_tag(short_name, container)

    def handle_pseudo_container(self, short_name, attrs):
        if self.top_json_container is None:
            container = JsonPseudoContainer()
        else:
            container = None
        self._push_tag(short_name, container)

    def unknown_starttag(self, tag, attrs):
        if tag.startswith(VAR_NS):
            short_name = tag[VAR_NS_LEN + 1:]
        elif tag.startswith(XHTML_NS):
            short_name = tag[XHTML_NS_LEN + 1:]
        else:
            short_name = tag

        if short_name is not None:
            if short_name == "string":
                self.handle_string(short_name, attrs)
            elif short_name == "input":
                self.handle_input(short_name, attrs, JsonInput)
            elif short_name == "textarea":
                self.handle_input(short_name, attrs, JsonTextArea)
            elif short_name == "popup":
                self.handle_input(short_name, attrs, JsonPopup)
            elif short_name == "component-content":
                self.current_json_container.show_content = True
            elif short_name == "foreach":
                self.handle_loop(short_name, attrs)
            elif short_name == "if":
                self.handle_if(short_name, attrs)
            elif short_name == "component":
                self.handle_component(short_name, attrs)
            elif short_name == "container":
                self.handle_container(short_name, attrs)
            elif short_name in self.pseudo_containers:
                self.handle_pseudo_container(short_name, attrs)
            elif short_name not in self.ignored:
                raise Exception("unsupported tag: %s" % short_name)

    def unknown_endtag(self, tag):
        if tag.startswith(VAR_NS):
            short_name = tag[VAR_NS_LEN + 1:]
        elif tag.startswith(XHTML_NS):
            short_name = tag[XHTML_NS_LEN + 1:]
        else:
            short_name = tag

        current_tag = self.tag_stack[-1]
        if current_tag.tag == short_name:
            if current_tag.json_container is not None:
                self.current_json_container = current_tag.parent_json_container
                ## print "restored %s from %s" % (str(new_cont), str(old_cont))
            self.tag_stack.pop()


if __name__ == "__main__":
    infilename = sys.argv[1]
    if len(sys.argv) > 2:
        outfilename = sys.argv[2]
    else:
        outfilename = None
    parser = Parser(infilename)
    try:
        parser.parse()
    except Exception, e:
        print >>sys.stderr, \
            "An exception occurred while parsing '%s':\n%s" \
            % (sys.argv[1], traceback.format_exc())
        sys.exit(-1)

    try:
        contents = parser.top_json_container.to_json(True)
    except Exception, e:
        print >>sys.stderr, \
            "An exception occurred while rendering '%s':\n%s" \
            % (sys.argv[1], traceback.format_exc())
        sys.exit(-1)

    if outfilename == "-":
        print contents
    else:
        if outfilename is None:
            ext_idx = infilename.rfind(".wox")
            if ext_idx > -1:
                outfilename = "%s.json" % infilename[:ext_idx]
            else:
                raise Exception("'%s' does not end with 'wox'")
        print "converting %s\n        to %s" % (infilename, outfilename)
        outf = open(outfilename, "w+")
        outf.write(contents)
        outf.close()
