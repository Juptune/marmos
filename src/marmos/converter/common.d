/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.common;

import dmd.common.outbuffer : OutBuffer;
import dmd.dsymbol : Dsymbol;

import marmos.context : MarmosContext;

package:

auto fqnRetroRange(Dsymbol symbol)
{
    static struct R
    {
        Dsymbol symbol;
        const(char)[] front;
        bool empty;

        this(Dsymbol sym)
        {
            this.symbol = sym;
            this.popFront();
        }

        void popFront()
        {
            if(this.symbol is null)
            {
                this.empty = true;
                return;
            }

            this.front = symbol.toString();
            this.symbol = this.symbol.parent;
        }
    }

    return R(symbol);
}

string[] fqn(Dsymbol symbol)
{
    import std.algorithm : reverse, map;
    import std.array     : array;

    string[] components = symbol.fqnRetroRange.map!(str => str.idup).array;
    return reverse(components);
}

bool isBaseObject(Dsymbol symbol, MarmosContext context)
{
    import std.algorithm : equal;
    return symbol.fqnRetroRange.equal(["Object", "object"]);
}

string toStringFromBuffer(scope void delegate(scope ref OutBuffer) populate)
{
    OutBuffer buffer;
    populate(buffer);
    return buffer[].idup;
}

void extractCommonInfo(DocModelT, AstNodeT)(scope ref DocModelT doc, scope AstNodeT node)
{
    import marmos.converter.docparser : parseDocComment;
    import marmos.converter.model     : DocVisibility, DocLinkage, DocStorageClass;

    import std.string : fromStringz;

    doc.name = (node.ident is null) ? "__anonymous" : node.ident.toString.idup;
    doc.line = node.loc.linnum;

    static if(__traits(compiles, { auto a = NodeT.init.storage_class; }))
        doc.storageClasses = listFromDmdBitFlags!DocStorageClass(cast(STC)node.storage_class);
    static if(__traits(compiles, { auto a = AstNodeT.init.linkage; }))
        doc.linkage = fromDmdEnum!DocLinkage(node.linkage);
    static if(__traits(compiles, { auto a = AstNodeT.init.visibility; }))
        doc.visibility = fromDmdEnum!DocVisibility(node.visibility.kind);
    static if(__traits(compiles, { auto a = AstNodeT.init.comment; }))
        doc.comment = parseDocComment(node.comment.fromStringz.idup);
}

DocT fromDmdEnum(DocT, EnumT)(EnumT value)
{
    import dmd.astenums : PURE;
    import std.traits : getUDAs;

    static if(is(EnumT == PURE)) // As PURE has multiple levels that correspond to one keyword, we need to special case it.
    {
        return value != PURE.impure ? DocStorageClass.pure_ : DocStorageClass.FAILSAFE;
    }
    else
    {
        alias DocTMembers = __traits(allMembers, DocT);
        static foreach(MemberName; DocTMembers)
        {{
            alias MemberSymbol = __traits(getMember, DocT, MemberName);
            static foreach(DmdFlag; __traits(getAttributes, MemberSymbol))
            {
                static if(is(typeof(DmdFlag) == EnumT))
                if(value == DmdFlag)
                    return MemberSymbol;
            }
        }}
    }

    return DocT.init;
}


DocT[] listFromDmdBitFlags(DocT, EnumT)(EnumT flags)
{
    import std.traits : getUDAs;

    DocT[] result;

    alias DocTMembers = __traits(allMembers, DocT);
    static foreach(MemberName; DocTMembers)
    {{
        alias MemberSymbol = __traits(getMember, DocT, MemberName);
        static foreach(DmdFlag; __traits(getAttributes, MemberSymbol))
        {
            if(flags & DmdFlag)
                result ~= MemberSymbol;
        }
    }}

    return result;
}