module marmos.converter.json;

import std.sumtype  : isSumType, match;
import std.json     : JSONValue;
import std.typecons : Nullable;

const JSON_TYPE_FIELD = "@type";

struct JsonType { string name; }
struct JsonField { string name; }

template JsonTypeNameOf(DocT)
{
    import std.traits : fullyQualifiedName, getUDAs;

    private alias JsonTypeUdas = getUDAs!(DocT, JsonType);
    static if(JsonTypeUdas.length > 0)
        enum JsonTypeNameOf = JsonTypeUdas[0].name;
    else
    {
        static if(is(DocT == P*, P))
            enum JsonTypeNameOf = JsonTypeNameOf!P;
        else
            enum JsonTypeNameOf = fullyQualifiedName!DocT;
    }
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
        {{
            static foreach(Uda; __traits(getAttributes, field))
            {
                static if(__traits(compiles, Uda.name))
                    enum fieldId = Uda.name;
            }
            static if(!__traits(compiles, fieldId))
                enum fieldId = __traits(identifier, field);

            if(name == fieldId)
            {
                result.tupleof[i] = jsonToDoc!(typeof(field))(val);
                continue Foreach;
            }
        }}

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
            static if(!isSumType!Type)
            {
                case JsonTypeNameOf!Type:
                    return T(jsonToDoc!Type(json));
            }
        }
        
        default:
            static foreach(Type; T.Types)
            {
                static if(isSumType!Type)
                {
                    try return T(jsonToDoc!Type(json));
                    finally {}
                    
                }
            }
            throw new Exception(format("Unexpected @type '%s' when converting JSON into %s", type, T.stringof));
    }
}

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == Nullable!N, N))
{
    import std.traits : Unqual;

    if(json.isNull)
        return T.init;

    return T(jsonToDoc!(Unqual!(typeof(T.init.get)))(json));
}

T jsonToDoc(T)(scope ref JSONValue json)
if(is(T == P*, P))
{
    if(json.isNull)
        return null;

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
    import std.format : format;
    import std.traits : EnumMembers;

    switch(json.str)
    {
        static foreach(Member; EnumMembers!T)
        {
            case cast(string)Member:
                return Member;
        }

        default:
            throw new Exception(format("Unexpected value for enum %s: %s", T.stringof, json.str));
    }
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