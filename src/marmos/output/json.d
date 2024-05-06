/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.output.json;

import std.sumtype : SumType, match;
import std.traits  : isIntegral, isInstanceOf;

struct JsonWriter
{
    import std.array : Appender;

    private
    {
        Appender!(char[]) _buffer;
        size_t            _indent;
    }

    @disable this(this); // to prevent accidental copying.

    void reserve(size_t size = 1024 * 1024 * 1024)
    {
        this._buffer.reserve(size);
    }

    void putObject(bool delegate(uint, scope ref JsonWriter) putter)
    {
        this._buffer.put("{\n");
        this._indent += 2;
        this.putIndent();
        
        uint i = 0;
        while(putter(i++, this))
        {
            this._buffer.put(",\n");
            this.putIndent();
        }

        this._buffer.put('\n');
        this._indent -= 2;
        this.putIndent();
        this._buffer.put('}');
    }

    void putArray(bool delegate(uint, scope ref JsonWriter) putter)
    {
        this._buffer.put("[\n");
        this._indent += 2;
        this.putIndent();
        
        uint i = 0;
        while(putter(i++, this))
        {
            this._buffer.put(",\n");
            this.putIndent();
        }

        this._buffer.put('\n');
        this._indent -= 2;
        this.putIndent();
        this._buffer.put(']');
    }

    void putInt(IntT)(IntT value)
    if(isIntegral!IntT)
    {
        import std.format : formattedWrite;
        this._buffer.formattedWrite("%s", value);
    }

    void putKey(scope const(char)[] key)
    {
        this.putString(key);
        this._buffer.put(": ");
    }

    void putString(scope const(char)[] str)
    {
        import std.ascii  : isASCII;
        import std.format : formattedWrite;
        import std.uni    : isUnicodeControl = isControl, byCodePoint;

        this._buffer.put('"');
        foreach(c; str.byCodePoint)
        {
            switch(c)
            {
                case '\\':
                    this._buffer.put("\\\\");
                    continue;
                case '"':
                    this._buffer.put("\\\"");
                    continue;
                case '\b':
                    this._buffer.put("\\b");
                    continue;
                case '\f':
                    this._buffer.put("\\f");
                    continue;
                case '\n':
                    this._buffer.put("\\n");
                    continue;
                case '\r':
                    this._buffer.put("\\r");
                    continue;
                case '\t':
                    this._buffer.put("\\t");
                    continue;
                default: break;
            }

            if(c > 0xFFFF || c.isUnicodeControl)
            {
                const bytes = 
                    c & 0xFFFF_0000_0000_0000
                    ? 4
                        : c & 0x0000_FFFF_0000_0000
                        ? 3
                            : c & 0x0000_0000_FFFF_0000
                            ? 2
                                : 1;

                if(bytes == 4)
                {
                    this._buffer.put("\\u");
                    this._buffer.formattedWrite("%04x", c & 0xFFFF_0000_0000_0000);
                }
                if(bytes >= 3)
                {
                    this._buffer.put("\\u");
                    this._buffer.formattedWrite("%04x", c & 0x0000_FFFF_0000_0000);
                }
                if(bytes >= 2)
                {
                    this._buffer.put("\\u");
                    this._buffer.formattedWrite("%04x", c & 0x0000_0000_FFFF_0000);
                }
                this._buffer.put("\\u");
                this._buffer.formattedWrite("%04x", c & 0x0000_0000_0000_FFFF);
                continue;
            }

            this._buffer.put(c);
        }
        this._buffer.put('"');
    }

    void putNull()
    {
        this._buffer.put("null");
    }

    void putBool(bool value)
    {
        this._buffer.put(value ? "true" : "false");
    }

    string toString() const
    {
        return this._buffer.data.idup;
    }

    private void putIndent()
    {
        foreach(_; 0..this._indent)
            this._buffer.put(' ');
    }
}

void toJson(string str, scope ref JsonWriter json)
{
    json.putString(str);
}

void toJson(IntT)(IntT value, scope ref JsonWriter json)
if(isIntegral!IntT && !is(IntT == enum))
{
    json.putInt(value);
}

void toJson(bool value, scope ref JsonWriter json)
{
    json.putBool(value);
}

void toJson(T)(T[] arr, scope ref JsonWriter json)
if(!is(T : const char))
{
    json.putArray((uint i, scope ref JsonWriter json)
    {
        if(arr.length == 0)
            return false;

        toJson(arr[i], json);
        return i + 1 < arr.length;
    });
}

void toJson(SumTypeArgs...)(SumType!(SumTypeArgs) sum, scope ref JsonWriter json)
{
    sum.match!((all) => toJson(all, json));
}

void toJson(StructT)(StructT obj, scope ref JsonWriter json)
if(is(StructT == struct) && !isInstanceOf!(SumType, StructT))
{
    import std.traits : fullyQualifiedName;
    immutable DocTypeStringOf(alias T) = fullyQualifiedName!T;

    json.putObject((uint i, scope ref JsonWriter json)
    {
        static foreach(tupI; 0..StructT.tupleof.length)
        if(i == tupI)
        {
            json.putKey(StructT.tupleof[tupI].stringof);
            toJson(obj.tupleof[tupI], json);
            return true;
        }

        if(i == StructT.tupleof.length)
        {
            json.putKey("@type");
            json.putString(DocTypeStringOf!StructT);
            return false;
        }

        return false;
    });
}

void toJson(EnumT)(EnumT value, scope ref JsonWriter json)
if(is(EnumT == enum))
{
    import std.format : formattedWrite;
    import std.traits : OriginalType;

    static if(is(OriginalType!EnumT == string))
        json.putString(value);
    else
        json._buffer.formattedWrite("\"%s\"", value);
}