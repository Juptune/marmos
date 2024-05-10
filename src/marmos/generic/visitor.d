/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.generic.visitor;

import dmd.astcodegen : ASTCodegen;
import dmd.dmodule    : Module;
import dmd.visitor    : SemanticTimePermissiveVisitor;
import std.file       : getcwd;
import marmos.generic.model, marmos.generic.docparser;

extern(C++) class DocVisitor : SemanticTimePermissiveVisitor
{
    alias visit = SemanticTimePermissiveVisitor.visit;

    DocAggregateType[] types;
    DocSoloType[] soloTypes;
    string basePath;

    extern(D) this(string basePath)
    {
        this.basePath = basePath;
    }

    private void genericSoloTypeVisit(TypeT, NodeT)(
        scope ref TypeT result,
        scope NodeT node
    )
    {
        import dmd.dsymbol : Dsymbol;
        import std.array   : Appender;
        import std.string  : fromStringz;

        result.name = (node.ident is null) ? "__anonymous" : node.ident.toString.idup;
        result.location = DocLocation.from(node.loc, this.basePath);

        static if(__traits(compiles, { auto a = NodeT.init.storage_class; }))
            result.storageClasses = listFromDmdBitFlags!DocStorageClass(node.storage_class);
        static if(__traits(compiles, { auto a = NodeT.init.linkage; }))
            result.linkage = fromDmdEnum!DocLinkage(node.linkage);
        static if(__traits(compiles, { auto a = NodeT.init.visibility; }))
            result.visibility = fromDmdEnum!DocVisibility(node.visibility.kind);

        result.comment = parseDocComment(node.comment.fromStringz.idup);
    }

    private void genericTypeVisit(TypeT, NodeT)(
        scope ref TypeT result,
        scope NodeT node
    )
    {
        this.genericSoloTypeVisit(result, node);

        if(node.members !is null)
        {
            scope visitor = new DocVisitor(this.basePath);
            foreach(member; *node.members)
                member.accept(visitor);
            result.members = visitor.soloTypes;
            result.nestedTypes = visitor.types;
        }
    }

    extern(D) static DocModule visitModule(Module mod, string basePath = getcwd)
    {
        import std.algorithm : map;
        import std.array     : array;
        import std.range     : chain;
        import std.string    : fromStringz;
        
        DocModule result;
        result.languageEdition = mod.edition;
        result.location        = DocLocation.from(mod.loc, basePath);
        result.isPackageFile   = mod.isPackageFile;
        result.comment         = parseDocComment(mod.comment.fromStringz.idup);

        if(mod.md !is null)
        {
            result.nameComponents = 
                mod.md.packages
                .map!(id => id.toString.idup)
                .chain([mod.md.id.toString.idup])
                .array;
        }
        else
            result.nameComponents = ["__anonymous"];

        if(mod.members !is null)
        {
            scope visitor = new DocVisitor(basePath);
            foreach(member; *mod.members)
                member.accept(visitor);
            result.soloTypes = visitor.soloTypes;
            result.types = visitor.types;
        }

        return result;
    }

    override void visit(ASTCodegen.StructDeclaration node)
    {
        DocStruct result;
        this.genericTypeVisit(result, node);

        this.types ~= DocAggregateType(result);
    }
    
    override void visit(ASTCodegen.ClassDeclaration node)
    {
        DocClass result;
        this.genericTypeVisit(result, node);

        this.types ~= DocAggregateType(result);
    }

    override void visit(ASTCodegen.InterfaceDeclaration node)
    {
        DocInterface result;
        this.genericTypeVisit(result, node);

        this.types ~= DocAggregateType(result);
    }

    override void visit(ASTCodegen.UnionDeclaration node)
    {
        DocUnion result;
        this.genericTypeVisit(result, node);

        this.types ~= DocAggregateType(result);
    }

    override void visit(ASTCodegen.TemplateDeclaration node)
    {
        if(node.onemember && node.ident == node.onemember.ident) // Eponymous template with no extra members
        {
            // Quirk: This appends the template comment to the member comment.
            //        I'd prefer this to be the other way around but there's no functionality for that in Dsymbol currently.
            node.onemember.addComment(node.comment);
            node.onemember.accept(this);
            return;
        }

        DocTemplate result;
        this.genericTypeVisit(result, node);

        this.types ~= DocAggregateType(result);
    }

    override void visit(ASTCodegen.EnumDeclaration node)
    {
        DocEnum result;
        this.genericTypeVisit(result, node);

        this.types ~= DocAggregateType(result);
    }

    override void visit(ASTCodegen.AliasDeclaration node)
    {
        DocAlias result;
        this.genericSoloTypeVisit(result, node);

        this.soloTypes ~= DocSoloType(result);
    }

    override void visit(ASTCodegen.FuncDeclaration node)
    {
        DocFunction result;
        this.genericSoloTypeVisit(result, node);

        this.soloTypes ~= DocSoloType(result);
    }

    override void visit(ASTCodegen.VarDeclaration node)
    {
        DocVariable result;
        this.genericSoloTypeVisit(result, node);

        this.soloTypes ~= DocSoloType(result);
    }

    override void visit(ASTCodegen.AttribDeclaration node)
    {
        if(node.decl !is null)
        {
            foreach(member; *node.decl)
                member.accept(this);
        }
    }
}

private:

import dmd.astenums : STC, LINK;
import dmd.dsymbol  : Visibility;

DocT fromDmdEnum(DocT, EnumT)(EnumT value)
{
    import std.traits : getUDAs;

    alias DocTMembers = __traits(allMembers, DocT);
    static foreach(MemberName; DocTMembers)
    {{
        alias MemberSymbol = __traits(getMember, DocT, MemberName);
        enum DmdFlag = __traits(getAttributes, MemberSymbol)[0];
        if(value == DmdFlag)
            return MemberSymbol;
    }}

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
        enum DmdFlag = __traits(getAttributes, MemberSymbol)[0];
        if(flags & DmdFlag)
            result ~= MemberSymbol;
    }}

    return result;
}
///
unittest
{
    import std.format : format;
    const list = listFromDmdBitFlags!DocStorageClass(STC.static_ | STC.abstract_ | STC.final_);
    const expected = [DocStorageClass.static_, DocStorageClass.final_, DocStorageClass.abstract_];
    assert(list == expected, format("%s != %s", list, expected));
}