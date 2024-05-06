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

    DocType[] types;
    DocNonType[] nonTypes;
    string basePath;

    extern(D) this(string basePath)
    {
        this.basePath = basePath;
    }

    private void genericNonTypeVisit(TypeT, NodeT)(
        scope ref TypeT result,
        scope NodeT node
    )
    {
        import dmd.dsymbol : Dsymbol;
        import std.array   : Appender;
        import std.string  : fromStringz;

        result.name = node.ident.toString.idup;
        result.location = DocLocation.from(node.loc, this.basePath);

        static if(__traits(compiles, { auto a = NodeT.init.storage_class; }))
            result.storageClasses = listFromDmdBitFlags!DocStorageClass(node.storage_class);
        static if(__traits(compiles, { auto a = NodeT.init.linkage; }))
            result.linkage = fromDmdEnum!DocLinkage(node.linkage);
        static if(__traits(compiles, { auto a = NodeT.init.visibility; }))
            result.visibility = fromDmdEnum!DocVisibility(node.visibility.kind);

        if(node.comment is null || node.comment.fromStringz.length == 0)
        {
            // TODO: See if we can use the original type's comment
        }
        else
            result.comment = parseDocComment(node.comment.fromStringz.idup);
    }

    private void genericTypeVisit(TypeT, NodeT)(
        scope ref TypeT result,
        scope NodeT node
    )
    {
        this.genericNonTypeVisit(result, node);

        if(node.members !is null)
        {
            scope visitor = new DocVisitor(this.basePath);
            foreach(member; *node.members)
                member.accept(visitor);
            result.members = visitor.nonTypes;
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
            result.nonTypes = visitor.nonTypes;
            result.types = visitor.types;
        }

        return result;
    }

    override void visit(ASTCodegen.StructDeclaration node)
    {
        DocStruct result;
        this.genericTypeVisit(result, node);

        this.types ~= DocType(result);
    }
    
    override void visit(ASTCodegen.ClassDeclaration node)
    {
        DocClass result;
        this.genericTypeVisit(result, node);

        this.types ~= DocType(result);
    }

    override void visit(ASTCodegen.InterfaceDeclaration node)
    {
        DocInterface result;
        this.genericTypeVisit(result, node);

        this.types ~= DocType(result);
    }

    override void visit(ASTCodegen.UnionDeclaration node)
    {
        DocUnion result;
        this.genericTypeVisit(result, node);

        this.types ~= DocType(result);
    }

    override void visit(ASTCodegen.TemplateDeclaration node)
    {
        if(node.onemember && node.ident == node.onemember.ident) // Eponymous template with no extra members
        {
            node.onemember.addComment(node.comment);
            node.onemember.accept(this);
            return;
        }

        DocTemplate result;
        this.genericTypeVisit(result, node);

        this.types ~= DocType(result);
    }

    override void visit(ASTCodegen.EnumDeclaration node)
    {
        DocEnum result;
        this.genericNonTypeVisit(result, node);

        this.nonTypes ~= DocNonType(result);
    }

    override void visit(ASTCodegen.AliasDeclaration node)
    {
        DocAlias result;
        this.genericNonTypeVisit(result, node);

        this.nonTypes ~= DocNonType(result);
    }

    override void visit(ASTCodegen.FuncDeclaration node)
    {
        DocFunction result;
        this.genericNonTypeVisit(result, node);

        this.nonTypes ~= DocNonType(result);
    }

    override void visit(ASTCodegen.VarDeclaration node)
    {
        DocVariable result;
        this.genericNonTypeVisit(result, node);

        this.nonTypes ~= DocNonType(result);
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