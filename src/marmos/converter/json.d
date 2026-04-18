/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.json;

import std.sumtype  : isSumType, match;
import std.json     : JSONValue;
import std.typecons : Nullable;

const JSON_TYPE_FIELD = "@type";

template JsonTypeNameOf(DocT)
{
    import std.traits : fullyQualifiedName;
    enum JsonTypeNameOf = fullyQualifiedName!DocT;
}

/++ doc -> json ++/

JSONValue docToJson(DocT)(DocT value)
if(is(DocT == struct) && !isSumType!DocT && !is(DocT == Nullable!N, N))
{
    JSONValue[string] dict;

    dict[JSON_TYPE_FIELD] = JsonTypeNameOf!DocT;
    static foreach(i, field; value.tupleof)
        dict[__traits(identifier, field)] = docToJson(value.tupleof[i]);

    return JSONValue(dict);
}

JSONValue docToJson(DocT)(DocT value)
if(isSumType!DocT)
{
    import std.meta : staticMap;

    // I have to instantiate any docToJson calls outside of .match so I can get actual error messages.
    alias Handler(T) = docToJson!T;
    alias Handlers = staticMap!(Handler, DocT.Types);

    return value.match!Handlers;
}

JSONValue docToJson(DocT)(DocT value)
if(is(DocT == Nullable!N, N))
{
    if(value.isNull)
        return JSONValue(null);

    return docToJson(value.get);
}

JSONValue docToJson(DocT)(DocT value)
if(is(DocT == P*, P))
{
    if(value is null)
        return JSONValue(null);

    return docToJson(*value);
}

JSONValue docToJson(DocT)(DocT value)
if(is(DocT == V[], V))
{
    static if(!is(DocT == string))
    {
        JSONValue[] array;
        foreach(v; value)
            array ~= docToJson(v);
        return JSONValue(array);
    }
    else
        return JSONValue(value);
}

JSONValue docToJson(DocT)(DocT value)
if(__traits(compiles, { auto a = JSONValue(DocT.init); }) && !is(DocT == V[], V))
{
    return JSONValue(value);
}

/++ json -> doc ++/

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == struct) && !isSumType!T && !is(T == Nullable!N, N))
{
    import std.exception    : enforce;
    import std.format       : format;

    T result;

    enforce(json.objectNoRef[JSON_TYPE_FIELD].str == JsonTypeNameOf!T, format(
        "When converting JSON into %s, expected @type to be '%s' but got '%s'",
        T.stringof,
        JsonTypeNameOf!T,
        json.objectNoRef[JSON_TYPE_FIELD].str
    ));

    Foreach: foreach(name, val; json.objectNoRef)
    {
        static foreach(i, field; result.tupleof)
        {
            if(name == __traits(identifier, field))
            {
                result.tupleof[i] = jsonToDoc!(typeof(field))(val);
                continue Foreach;
            }
        }

        if(name == "@type") continue; // Already handled

        throw new Exception(format("Unexpected key '%s' when converting JSON into %s", name, T.stringof));
    }

    return result;
}

T jsonToDoc(T)(scope ref JSONValue json)
if(isSumType!T)
{
    import std.format : format;

    const type = json.objectNoRef[JSON_TYPE_FIELD].str;

    switch(type)
    {
        static foreach(Type; T.Types)
        {
            case JsonTypeNameOf!Type:
                return T(jsonToDoc!Type(json));
        }
        
        default:
            throw new Exception(format("Unexpected @type '%s' when converting JSON into %s", type, T.stringof));
    }
}

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == Nullable!N, N))
{
    import std.traits : Unqual;

    return T(jsonToDoc!(Unqual!(typeof(T.init.get)))(json));
}

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == P*, P))
{
    static if(is(T == P*, P)) // So I can actually access `P`
    {
        auto value = new P();
        *value = jsonToDoc!P(json);
    }
    return value;
}

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == enum))
{
    import std.conv : to;
    return json.str.to!T;
}

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == V[], V) && !is(T == string))
{
    T array;

    foreach(val; json.arrayNoRef)
        array ~= jsonToDoc!(typeof(array[0]))(val);

    return array;
}

T jsonToDoc(T)(scope ref JSONValue json)
if(__traits(compiles, { auto a = JSONValue.init.get!T; }) && !is(T == enum))
{
    return json.get!T;
}