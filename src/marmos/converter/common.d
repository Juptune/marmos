/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.common;

import dmd.attrib           : UserAttributeDeclaration;
import dmd.common.outbuffer : OutBuffer;
import dmd.dsymbol          : Dsymbol;
import dmd.dmodule          : Module;

import marmos.context         : MarmosContext;
import marmos.converter.model : DocTypeRefRaw, DocUda;

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

void extractCommonInfo(DocModelT, AstNodeT)(
    scope ref DocModelT doc, 
    scope AstNodeT node, 
    MarmosContext context, 
    Module moduleBeingVisited
)
{
    import std.string : fromStringz;

    import dmd.astenums : STC;

    import marmos.converter.docparser : parseDocComment;
    import marmos.converter.model     : DocVisibility, DocLinkage, DocStorageClass;

    doc.name = (node.ident is null) ? "__anonymous" : node.ident.toString.idup;
    doc.line = node.loc.linnum;

    static if(__traits(compiles, { auto a = AstNodeT.init.storage_class; }))
        doc.storageClasses = listFromDmdBitFlags!DocStorageClass(cast(STC)node.storage_class);
    static if(__traits(compiles, { auto a = AstNodeT.init.linkage; }))
        doc.linkage = fromDmdEnum!DocLinkage(node.linkage);
    static if(__traits(compiles, { auto a = AstNodeT.init.visibility; }))
        doc.visibility = fromDmdEnum!DocVisibility(node.visibility.kind);
    static if(__traits(compiles, { auto a = AstNodeT.init.comment; }))
    {
        const commentString = node.comment.fromStringz.idup;
        if(commentString.length > 0)
            doc.comment = parseDocComment(commentString);
    }

    static if(__traits(hasMember, AstNodeT, "userAttribDecl") && __traits(hasMember, DocModelT, "udas"))
    {
        if(node.userAttribDecl !is null)
            doc.udas = getUdas(node.userAttribDecl, context, moduleBeingVisited);
    }
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

bool probablySameSymbolRef(DocTypeRefRaw actual, DocTypeRefRaw original)
{
    import std.sumtype              : match;
    import marmos.converter.model   : DocSymbolReference;

    return actual.match!(
        (DocSymbolReference symActual) => original.match!(
            (DocSymbolReference symOriginal) {
                if(symOriginal.moduleFqnComponents.length == 0 && symOriginal.items.length == 0 && symActual.items.length > 0) // @suppress(dscanner.style.long_line)
                    return true; // Special case: `original` is basically a null reference, so pretend they're the same symbol in order to make it be omitted.

                return 
                    symActual.moduleFqnComponents.length > 0
                    && symOriginal.moduleFqnComponents.length == 0
                    && symActual.items == symOriginal.items;
            },
            (_) => false
        ),
        (_) => false
    );
}

DocUda[] getUdas(UserAttributeDeclaration decl, MarmosContext context, Module moduleBeingVisited)
{
    import marmos.converter.model    : DocExpressionUda;
    import marmos.converter.visitors : ExpressionVisitor;

    DocUda[] udas;

    if(decl.atts is null)
        return udas;

    foreach(exp; *decl.atts)
    {
        scope expressionVisitor = new ExpressionVisitor(context, moduleBeingVisited);
        exp.accept(expressionVisitor);
        udas ~= DocUda(DocExpressionUda(expressionVisitor.getResult()));
    }

    return udas;
}