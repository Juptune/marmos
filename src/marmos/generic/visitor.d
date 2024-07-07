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
import std.typecons   : Nullable, nullable;
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
        DocTemplate result;
        this.genericTypeVisit(result, node);
        result.isEponymous = (node.onemember && node.ident == node.onemember.ident);

        this.types ~= DocAggregateType(result);
    }

    override void visit(ASTCodegen.EnumDeclaration node)
    {
        DocEnum result;
        this.genericTypeVisit(result, node);

        auto type = parseTypeReference(node.memtype, null);
        if(!type.isNull)
            result.baseType = type.get;
        else
            result.baseType.nameComponents = ["int"];

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
        import std.algorithm : countUntil, remove;

        DocFunction result;
        this.genericSoloTypeVisit(result, node);
        result.parameters = extractRuntimeParameters(node);

        if(node.type && node.type.isTypeFunction())
        {
            auto returnType = parseTypeReference(node.type.isTypeFunction().next, null);
            if(!returnType.isNull)
                result.returnType = returnType.get;

            const autoIndex = result.storageClasses.countUntil(DocStorageClass.auto_);
            if(returnType.isNull && autoIndex != -1)
            {
                result.returnType.nameComponents = ["auto"];
                result.storageClasses = result.storageClasses.remove(autoIndex);
            }
        }

        this.soloTypes ~= DocSoloType(result);
    }

    override void visit(ASTCodegen.VarDeclaration node)
    {
        DocVariable result;
        this.genericSoloTypeVisit(result, node);

        auto origType = node.originalType;
        if(auto member = node.isEnumMember()) // Try to extract type from enum member's special fields.
            origType = (member.origValue !is null) ? member.origValue.type : member.origType;

        auto type = parseTypeReference(node.type, origType);
        if(!type.isNull)
            result.type = type.get;
        else
        {
            result.type.nameComponents = ["__enumMember"];
            result.comment.addMarmosNoteComment(
                "Type may be inaccurate as marmos couldn't figure it out - potentially needs semantic analysis."
            );
        }

        if(node._init)
        {
            import dmd.astenums : InitKind;
            final switch(node._init.kind) with(InitKind)
            {
                case void_:
                    result.initialValue = "void";
                    break;

                case default_:
                    result.initialValue = "{}";
                    break;

                case error:
                    result.initialValue = "<Error?>";
                    break;

                case struct_:
                    result.initialValue = "<todo: support struct literal>";
                    break;

                case array:
                    result.initialValue = "<todo: support array literal>";
                    break;

                case exp:
                    if(auto exp = node._init.isExpInitializer())
                    {
                        if(exp.exp)
                            result.initialValue = exp.exp.toString.idup;
                        else
                            result.initialValue = ""; // No initializer, despite being an expression initializer
                    }
                    else
                        result.initialValue = "<?: Not an ExpInitializer despite being an exp kind>";
                    break;

                case C_:
                    result.initialValue = "<todo: support C-style initializer>";
                    break;
            }
        }

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

extern(C++) class DocTypeVisitor : SemanticTimePermissiveVisitor
{
    import std.string : fromStringz;
    alias visit = SemanticTimePermissiveVisitor.visit;

    DocTypeReference result;

    extern(D) this()
    {
    }

    void reset()
    {
        this.result = DocTypeReference.init;
    }

    override void visit(ASTCodegen.TypeBasic node)
    {
        this.result.nameComponents ~= node.kind.fromStringz.idup;
    }

    override void visit(ASTCodegen.TypeIdentifier node)
    {
        this.result.nameComponents ~= node.ident.toString.idup;
    }

    override void visit(ASTCodegen.TypeSArray node)
    {
        node.next.accept(this);
        this.result.nameComponents ~= "[";
        if(node.dim)
            this.result.nameComponents ~= node.dim.toString.idup; // TODO: Try ctfe
        this.result.nameComponents ~= "]";
    }

    override void visit(ASTCodegen.TypeDArray node)
    {
        node.next.accept(this);
        this.result.nameComponents ~= ["[", "]"];
    }

    override void visit(ASTCodegen.TypeAArray node)
    {
        node.next.accept(this);
        this.result.nameComponents ~= "[";
        if(node.index)
            node.index.accept(this);
        this.result.nameComponents ~= "]";
    }

    override void visit(ASTCodegen.TypePointer node)
    {
        node.next.accept(this);
        this.result.nameComponents ~= "*";
    }

    override void visit(ASTCodegen.TypeTypeof node)
    {
        this.result.nameComponents ~= [
            "typeof(",
            node.exp.toString.idup,
            ")"
        ];
    }

    override void visit(ASTCodegen.TypeReturn node)
    {
        this.result.nameComponents ~= ["typeof(", "return", ")"];
    }

    override void visit(ASTCodegen.TypeInstance node)
    {
        bool isFirst = true;
        this.result.nameComponents ~= [node.tempinst.name.toString.idup, "!("];
        foreach(arg; *node.tempinst.tiargs)
        {
            if(!isFirst)
                this.result.nameComponents ~= ",";
            isFirst = false;
            this.result.nameComponents ~= arg.toString.idup;
        }
        this.result.nameComponents ~= ")";
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

DocRuntimeParameter[] extractRuntimeParameters(ASTCodegen.FuncDeclaration node)
{
    DocRuntimeParameter[] params;

    auto type = node.originalType ? node.originalType : node.type;
    if(!type)
        return params;

    auto funcType = type.isTypeFunction();
    auto paramList = funcType.parameterList;

    scope typeVisitor = new DocTypeVisitor();
    foreach(i, param; paramList)
    {
        typeVisitor.reset();
        param.type.accept(typeVisitor);

        DocRuntimeParameter docParam;
        docParam.type = typeVisitor.result;
        docParam.name = param.ident ? param.ident.toString.idup : "__anonymous";

        params ~= docParam;
    }

    return params;
}

Nullable!DocTypeReference parseTypeReference(ASTCodegen.Type type, ASTCodegen.Type originalType)
{
    auto node = originalType ? originalType : type;
    if(node is null)
        return typeof(return).init;

    scope visitor = new DocTypeVisitor();
    visitor.reset();
    node.accept(visitor);
    return visitor.result.nullable;
}

void addMarmosNoteComment(ref DocComment comment, string note)
{
    auto block = DocCommentBlock(
        DocCommentParagraphBlock([
            DocCommentInline(
                DocCommentTextInline(note)
            )
        ])
    );
    
    if(comment.sections.length > 0 && comment.sections[$-1].title == "(Marmos Notes)")
        comment.sections[$-1].blocks ~= block;
    else
        comment.sections ~= DocCommentSection("(Marmos Notes)", [block]);
}