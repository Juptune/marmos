module marmos.converter.json;

import std;
const JSON_TYPE_FIELD = "@type";

struct JsonType { string name; }
struct JsonField { string name; }

template JsonTypeNameOf(DocT)
{
alias JsonTypeUdas = getUDAs!(DocT, JsonType);
    static if(JsonTypeUdas.length )
        enum JsonTypeNameOf = JsonTypeUdas[0].name;
    else
            enum JsonTypeNameOf = fullyQualifiedName!DocT;
}

/++ json -> doc ++/

T jsonToDoc(T)(JSONValue json)
if(is(T == struct) && !isSumType!T )
{
    T result;

foreach(name, val; json.objectNoRef)
        static foreach(i, field; result.tupleof)
        {{
                enum fieldId = __traits(identifier, field);

            if(name == fieldId)
                result.tupleof[i] = jsonToDoc!(typeof(field))(val);
        }}

    return result;
}

T jsonToDoc(T)(JSONValue json)
if(isSumType!T)
{
    const type = json.objectNoRef[JSON_TYPE_FIELD].str;

    switch(type)
    {
foreach(Type; T.Types)
                case JsonTypeNameOf!Type:
                    return T(jsonToDoc!Type(json));
        
        default:
                    try return T();
                    finally {}
    }
}

T jsonToDoc(T)(JSONValue json)
if(is(T == V[], V) && !is(T == string))
{
    T array;

    foreach(val; json.arrayNoRef)
        array ~= jsonToDoc!(typeof(array[0]))(val);

    return array;
}

T jsonToDoc(T)(JSONValue json)
if(__traits(compiles, { JSONValue.init.get!T; }) )
{
    return json.get!T;
}