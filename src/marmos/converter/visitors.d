/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.visitors;

import marmos.converter.common : extractCommonInfo, fqn;
import marmos.context          : MarmosContext;

import marmos.converter.model; // Intentionally everything.

import std.logger   : tracef, warningf;
import std.string   : fromStringz;
import std.sumtype  : match;
import std.typecons : Nullable;

import dmd.astcodegen : ASTCodegen;
import dmd.astenums   : ThreeState;
import dmd.dmodule    : Module;
import dmd.dsymbol    : Dsymbol;
import dmd.visitor    : SemanticTimePermissiveVisitor;

private abstract class Visitor : SemanticTimePermissiveVisitor
{
    alias visit = SemanticTimePermissiveVisitor.visit;

    private string _typeName;

    protected
    {
        // Set if the parent visitor is for an enum, which has the following effects:
        //  * For UnaryDefVisitor - this'll stop direct EnumMembers from having a type ref attached to them, which _greatly_ reduces the file size each member takes up.
        bool parentIsEnum;

        MarmosContext context;
        Module moduleBeingVisited;

        this(string typeName, MarmosContext context, Module mod, bool parentIsEnum)
        {
            this._typeName = typeName;
            this.context = context;
            this.moduleBeingVisited = mod;
            this.parentIsEnum = parentIsEnum;
        }

        bool belongsToThisModule(Dsymbol symbol)
        {
            Dsymbol parent = symbol;
            while(parent !is null && !parent.isModule)
                parent = parent.parent;
        
            if(parent is null)
                return false;

            if(auto mod = parent.isModule)
            {
                if(mod !is this.moduleBeingVisited)
                    return false;
            }

            return true;
        }
    }

    override extern(C++):

    void visit(ASTCodegen.Parameter node){ warningf("[%s] unhandled Parameter: %s", _typeName, node); }
    void visit(ASTCodegen.Statement node){ warningf("[%s] unhandled Statement: %s", _typeName, node); }
    void visit(ASTCodegen.Type node){ warningf("[%s] unhandled Type: %s %s", _typeName, node.kind.fromStringz, node); }
    void visit(ASTCodegen.Expression node){ warningf("[%s] unhandled Expression: %s", _typeName, node); }
    void visit(ASTCodegen.TemplateParameter node){ warningf("[%s] unhandled TemplateParameter: %s", _typeName, node); }
    void visit(ASTCodegen.Condition node){ warningf("[%s] unhandled Condition: %s", _typeName, node); }
    void visit(ASTCodegen.Initializer node){ warningf("[%s] unhandled Initializer: %s", _typeName, node); }

    void visit(ASTCodegen.Dsymbol node)
    { 
        if(!belongsToThisModule(node))
            return;

        warningf("[%s] unhandled Dsymbol: %s %s", _typeName, node.kind.fromStringz, node); 
    }
}

private mixin template VisitorCommon()
{
    this(MarmosContext context, Module mod, bool parentIsEnum = false)
    {
        super(typeof(this).stringof, context, mod, parentIsEnum);
    }
}

final class DefinitionVisitor : Visitor
{
    alias visit = Visitor.visit;

    DocAggregateDef[] aggregateDefinitions;
    DocUnaryDef[] unaryDefinitions;

    mixin VisitorCommon;

    private void visitAggregate(NodeT)(NodeT node)
    {
        scope visitor = new AggregateDefVisitor(super.context, super.moduleBeingVisited, super.parentIsEnum);
        node.accept(visitor);
        this.aggregateDefinitions ~= visitor.getResult();
    }

    private void visitUnary(NodeT)(NodeT node)
    {
        scope visitor = new UnaryDefVisitor(super.context, super.moduleBeingVisited, super.parentIsEnum);
        node.accept(visitor);
        this.unaryDefinitions ~= visitor.getResult();
    }

    override extern(C++):
    
    void visit(ASTCodegen.ClassDeclaration node) => visitAggregate(node);
    void visit(ASTCodegen.StructDeclaration node) => visitAggregate(node);
    void visit(ASTCodegen.EnumDeclaration node) => visitAggregate(node);
    void visit(ASTCodegen.TemplateDeclaration node) => visitAggregate(node);

    void visit(ASTCodegen.FuncDeclaration node) => visitUnary(node);
    void visit(ASTCodegen.AliasDeclaration node) => visitUnary(node);
    void visit(ASTCodegen.VarDeclaration node) => visitUnary(node);
    void visit(ASTCodegen.EnumMember node) => visitUnary(node);

    /++ AttribDeclaration ++/

    // Generic case for when we don't have a visitor for a specific implementation of AttribDeclaration.
    void visit(ASTCodegen.AttribDeclaration node)
    {
        if(node.decl is null)
        {
            tracef("ignoring %s %s as its .decl is null", node.kind.fromStringz, node);
            return;
        }

        foreach(subSymbol; *node.decl)
            subSymbol.accept(this);
    }

    /++ Other things intentionally ignored ++/

    void visit(ASTCodegen.Import){} // No point converting these into the model?
    void visit(ASTCodegen.TemplateInstance){} // This never(?) occurs naturally as standalone declarations, and is only a side effect of other declarations instantiating a template.
    void visit(ASTCodegen.TypeInfoDeclaration){} // This never(?) occurs naturally, it seems to be compiler generated only?
}

final class AggregateDefVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        Nullable!DocAggregateDef _result;
    }

    mixin VisitorCommon;


    DocAggregateDef getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    private void inlineMixinTemplates(ASTCodegen.TemplateMixin node, scope ref DocUnaryDef[] members, scope ref DocAggregateDef[] nestedTypes)
    {
        if(node.members is null)
            return;

        scope defVisitor = new DefinitionVisitor(super.context, super.moduleBeingVisited);
        foreach(member; *node.members)
            member.accept(defVisitor);

        if(node.importedScopes !is null)
        {
            foreach(scope_; *node.importedScopes)
            {
                if(auto templateMixin = scope_.isTemplateMixin())
                    this.inlineMixinTemplates(templateMixin, members, nestedTypes);
            }
        }

        members ~= defVisitor.unaryDefinitions;
        nestedTypes ~= defVisitor.aggregateDefinitions;
    }

    override extern(C++):
    
    void visit(ASTCodegen.ClassDeclaration node)
    {
        import marmos.converter.common : isBaseObject;

        DocClass doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Interfaces & base class
        // TODO: Figure out how to get the base class when semantic passes aren't ran... since .baseClass isn't the answer there
        if(node.baseClass !is null && !isBaseObject(node.baseClass, super.context))
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.baseClass.accept(typeRefVisitor);
            doc.baseClass = typeRefVisitor.getResult();
        }

        foreach(inter; node.interfaces)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            inter.type.accept(typeRefVisitor);
            doc.interfaces ~= typeRefVisitor.getResult();
        }

        // Members
        scope defVisitor = new DefinitionVisitor(super.context, super.moduleBeingVisited);
        if(node.members !is null)
        {
            foreach(member; *node.members)
                member.accept(defVisitor);
        }
        doc.members = defVisitor.unaryDefinitions;
        doc.nestedTypes = defVisitor.aggregateDefinitions;

        // Mixin template members (TODO: Should I make another model so it's possible to distinguish that these things came from a mixin template?)
        if(node.importedScopes !is null)
        {
            foreach(scope_; *node.importedScopes)
            {
                if(auto templateMixin = cast(ASTCodegen.TemplateMixin)scope_)
                    this.inlineMixinTemplates(templateMixin, doc.members, doc.nestedTypes);
            }
        }

        // Other
        if(node.stack)
            doc.storageClasses ~= DocStorageClass.scope_;
        if(node.isabstract == ThreeState.yes)
            doc.storageClasses ~= DocStorageClass.abstract_;

        this._result = DocAggregateDef(doc);
    }

    void visit(ASTCodegen.StructDeclaration node)
    {
        DocStruct doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Members
        scope defVisitor = new DefinitionVisitor(super.context, super.moduleBeingVisited);
        if(node.members !is null)
        {
            foreach(member; *node.members)
                member.accept(defVisitor);
        }
        doc.members = defVisitor.unaryDefinitions;
        doc.nestedTypes = defVisitor.aggregateDefinitions;

        // Mixin template members (TODO: Should I make another model so it's possible to distinguish that these things came from a mixin template?)
        if(node.importedScopes !is null)
        {
            foreach(scope_; *node.importedScopes)
            {
                if(auto templateMixin = cast(ASTCodegen.TemplateMixin)scope_)
                    this.inlineMixinTemplates(templateMixin, doc.members, doc.nestedTypes);
            }
        }

        this._result = DocAggregateDef(doc);
    }

    void visit(ASTCodegen.EnumDeclaration node)
    {
        DocEnum doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Members
        scope defVisitor = new DefinitionVisitor(super.context, super.moduleBeingVisited, parentIsEnum: true);
        if(node.members !is null)
        {
            foreach(member; *node.members)
                member.accept(defVisitor);
        }
        doc.members = defVisitor.unaryDefinitions;
        doc.nestedTypes = defVisitor.aggregateDefinitions;

        // Base type
        if(node.memtype !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.memtype.accept(typeRefVisitor);
            doc.baseTypeRef = typeRefVisitor.getResult();
        }

        this._result = DocAggregateDef(doc);
    }

    void visit(ASTCodegen.TemplateDeclaration node)
    {
        DocTemplate doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Parameters
        DocTemplateParam[] handleParams(ASTCodegen.TemplateParameters* params)
        {
            if(params is null)
                return null;

            DocTemplateParam[] result;

            foreach(param; *params)
            {
                scope templateParamVisitor = new TemplateParameterVisitor(super.context, super.moduleBeingVisited);
                param.accept(templateParamVisitor);
                result ~= templateParamVisitor.getResult();
            }

            return result;
        }
        doc.parameters = handleParams(node.parameters);
        doc.originalParameters = handleParams(node.origParameters);
        doc.isMixin = node.ismixin;

        // Members
        scope defVisitor = new DefinitionVisitor(super.context, super.moduleBeingVisited);
        if(node.members !is null)
        {
            foreach(member; *node.members)
                member.accept(defVisitor);
        }
        doc.members = defVisitor.unaryDefinitions;
        doc.nestedTypes = defVisitor.aggregateDefinitions;

        this._result = DocAggregateDef(doc);
    }
}

final class UnaryDefVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        Nullable!DocUnaryDef _result;
    }

    mixin VisitorCommon;

    DocUnaryDef getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    override extern(C++):

    void visit(ASTCodegen.FuncDeclaration node)
    {
        DocFunction doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Underlying function type
        if(node.type !is null) // TODO: When can this be null? Phobos is triggering it somewhere.
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.type.accept(typeRefVisitor);
            typeRefVisitor.getResult().raw.match!(
                (DocFunctionType ft) { doc.funcType = ft; },
                (_){ assert(false, "Unexpected result type"); }
            );
        }

        this._result = DocUnaryDef(doc);
    }

    void visit(ASTCodegen.Parameter node)
    {
        DocRuntimeParameter doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Type
        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.type.accept(typeRefVisitor);
        doc.typeRef = typeRefVisitor.getResult();

        // Default value
        if(node.defaultArg !is null)
        {
            scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
            node.defaultArg.accept(expressionVisitor);
            doc.defaultValueExpression = expressionVisitor.getResult();
        }

        this._result = DocUnaryDef(doc);
    }

    void visit(ASTCodegen.AliasDeclaration node)
    {
        DocAlias doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Type
        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        if(node.aliassym !is null)
            node.aliassym.accept(typeRefVisitor);
        else
            node.type.accept(typeRefVisitor);
        doc.symbolRef = typeRefVisitor.getResult();

        // Original type
        if(node.originalType !is null && node.originalType !is node.type)
        {
            import marmos.converter.common : probablySameSymbolRef;

            scope originalTypeVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.originalType.accept(originalTypeVisitor);

            // When semantics have ran, sometimes the originalType and actual type can resolve to the same thing.
            // e.g. `alias a = SomeStruct`, originalType will lack parent info, but the actual type has parent info, but they ultimately refer to the same type.
            //
            // So instead of having confusing output, we just keep the actual type version.
            if(!probablySameSymbolRef(doc.symbolRef.raw, originalTypeVisitor.getResult().raw))
            {
                doc.symbolRef.originalTypeRaw = new DocTypeRefRaw();
                *doc.symbolRef.originalTypeRaw.get = originalTypeVisitor.getResult().raw;
            }
        }

        this._result = DocUnaryDef(doc);
    }

    void visit(ASTCodegen.VarDeclaration node)
    {
        import dmd.astenums : STC;

        // I'm not _really_ sure why, but sometimes this overload gets called instead of EnumMembers.
        // Also _for some reason_ a lot of normal VarDeclarations can actually be casted to EnumMember... even when they're not really manifest constants? Hence the STC check.
        if(node.storage_class & STC.manifest)
        if(auto enumMember = cast(ASTCodegen.EnumMember)node)
        {
            this.visit(enumMember);
            return;
        }

        DocVariable doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // Type
        if(node.type !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.type.accept(typeRefVisitor);
            doc.typeRef = typeRefVisitor.getResult();
        }

        // Original type
        if(node.type !is null && node.originalType !is null && node.originalType !is node.type)
        {
            import marmos.converter.common : probablySameSymbolRef;

            scope originalTypeVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.originalType.accept(originalTypeVisitor);

            // When semantics have ran, sometimes the originalType and actual type can resolve to the same thing.
            // e.g. `alias a = SomeStruct`, originalType will lack parent info, but the actual type has parent info, but they ultimately refer to the same type.
            //
            // So instead of having confusing output, we just keep the actual type version.
            if(!probablySameSymbolRef(doc.typeRef.get.raw, originalTypeVisitor.getResult().raw))
            {
                doc.typeRef.get.originalTypeRaw = new DocTypeRefRaw();
                *doc.typeRef.get.originalTypeRaw.get = originalTypeVisitor.getResult().raw;
            }
        }

        // TODO: Handle initialiser.

        this._result = DocUnaryDef(doc);
    }

    void visit(ASTCodegen.EnumMember node)
    {
        if(node.origType !is null && node.origType !is node.originalType)
            assert(false, "why are these different?");

        DocManifestConstant doc;
        extractCommonInfo(doc, node, super.context, super.moduleBeingVisited);

        // EnumMembers that are directly attached to an enum, have a .type of the parent enum... which ends up using a _lot_ of space in the JSON output.
        // Since it's super easy to associate the members with the parent EnumDeclaration, it's worthwhile to omit things in this case.
        if(!super.parentIsEnum)
        {
            // Type
            if(node.type is null) // `enum E {}` will give a null .type, so we'll just substitute it with `int`
            {
                doc.typeRef = DocTypeRef(DocBasicType("int"));
            }
            else
            {
                scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
                node.type.accept(typeRefVisitor);
                doc.typeRef = typeRefVisitor.getResult();
            }

            // Original type
            if(node.originalType !is null && node.originalType !is node.type)
            {
                import marmos.converter.common : probablySameSymbolRef;

                scope originalTypeVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
                node.originalType.accept(originalTypeVisitor);

                if(!probablySameSymbolRef(doc.typeRef.get.raw, originalTypeVisitor.getResult().raw))
                {
                    doc.typeRef.get.originalTypeRaw = new DocTypeRefRaw();
                    *doc.typeRef.get.originalTypeRaw.get = originalTypeVisitor.getResult().raw;
                }
            }
        }

        // `enum E { a }` -> `a` will have a null value.
        if(node._init !is null && (cast(ASTCodegen.ExpInitializer)node._init).exp !is null) // _init is the underlying var used by `.value`, but `.value` always expects it to not be null... which it sometimes isn't.
        {
            scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
            node.value.accept(expressionVisitor);
            doc.valueExpression = expressionVisitor.getResult();
        }
        if(node.origValue !is null)
        {
            scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
            node.origValue.accept(expressionVisitor);
            doc.valueExpression = expressionVisitor.getResult();
        }

        this._result = DocUnaryDef(doc);
    }
}

final class TypeRefVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        Nullable!DocTypeRef _result;
    }

    mixin VisitorCommon;

    bool hasResult() => !this._result.isNull;

    DocTypeRef getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    private void setResult(TypeRefRawT, NodeT)(TypeRefRawT typeRef, NodeT node)
    {
        DocTypeRef doc;
        doc.raw = typeRef;

        static if(__traits(hasMember, NodeT, "isConst")) if(node.isConst)
            doc.storageClasses ~= DocStorageClass.const_;
        static if(__traits(hasMember, NodeT, "isImmutable")) if(node.isImmutable)
            doc.storageClasses ~= DocStorageClass.immutable_;
        static if(__traits(hasMember, NodeT, "isShared")) if(node.isShared)
            doc.storageClasses ~= DocStorageClass.shared_;

        this._result = doc;
    }

    override extern(C++):

    void visit(ASTCodegen.Expression node)
    {
        // This seems to happen naturally, I just can't really figure out why it happens and how to even interpret it.
        warningf("TypeRefVisitor was given an expression, providing fallback type: %s", node);
        this.setResult(DocBasicType("__MARMOS_BUG__"), node);
    }

    void visit(ASTCodegen.Dsymbol node)
    {
        // This _also_ seems to happen naturally, I just can't really figure out why it happens and how to even interpret it.
        warningf("TypeRefVisitor was given a DSymbol, providing fallback type: %s", node);
        this.setResult(DocBasicType("__MARMOS_BUG__"), node);
    }

    void visit(ASTCodegen.TypeTraits node)
    {
        this.setResult(DocBasicType("__traits(TODO)"), node);
    }

    void visit(ASTCodegen.TypeSlice node)
    {
        this.setResult(DocBasicType("slice[TODO]"), node);
    }

    void visit(ASTCodegen.TypeTypeof node)
    {
        this.setResult(DocBasicType("typeof(TODO)"), node);
    }

    void visit(ASTCodegen.TypeVector node)
    {
        this.setResult(DocBasicType("__vector(TODO)"), node);
    }

    void visit(ASTCodegen.TypeTuple node)
    {
        this.setResult(DocBasicType("__tuple(TODO)"), node);
    }

    void visit(ASTCodegen.TypeBasic node)
    {
        import dmd.astenums : TY;

        // There's no easy way it seems to just get the name of the type (e.g. `bool`) without any modifiers attached (e.g. `const(bool)`),
        // at least without using `toPrettyChars(false)` which allocates memory, which I feel should be very easy to avoid really.
        //
        // Soooooooo we're doing this instead.
        string name;
        switch(node.ty) with(TY)
        {
            case Tvoid: name = "void"; break;
            case Tint8: name = "byte"; break;
            case Tuns8: name = "ubyte"; break;
            case Tint16: name = "short"; break;
            case Tuns16: name = "ushort"; break;
            case Tint32: name = "int"; break;
            case Tuns32: name = "uint"; break;
            case Tint64: name = "long"; break;
            case Tuns64: name = "ulong"; break;
            case Tfloat32: name = "float"; break;
            case Tfloat64: name = "double"; break;
            case Tfloat80: name = "real"; break;
            case Timaginary32: name = "ifloat"; break;
            case Timaginary64: name = "idouble"; break;
            case Timaginary80: name = "ireal"; break;
            case Tcomplex32: name = "cfloat"; break;
            case Tcomplex64: name = "cdouble"; break;
            case Tcomplex80: name = "creal"; break;
            case Tbool: name = "bool"; break;
            case Tchar: name = "char"; break;
            case Twchar: name = "wchar"; break;
            case Tdchar: name = "dchar"; break;
            case Tnull: name = "null"; break;
            case Tnoreturn: name = "noreturn"; break;

            // Fallback since they're not specially handled (this generally shouldn't happen)
            default:
                import std.string : fromStringz;
                warningf("Unhandled TypeBasic: %s %s", node.ty, node);
                name = node.toPrettyChars(false).fromStringz.idup;
                break;
        }
        this.setResult(DocBasicType(name), node);
    }
    
    void visit(ASTCodegen.TypeNull node)
    {
        this.setResult(DocBasicType("typeof(null)"), node);
    }

    void visit(ASTCodegen.TypeNoreturn node)
    {
        this.setResult(DocBasicType("noreturn"), node);
    }

    void visit(ASTCodegen.TypeStruct node)
    {
        if(node.sym !is null)
        {
            node.sym.accept(this);
            return;
        }

        assert(false);
    }

    void visit(ASTCodegen.StructDeclaration node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.TypeClass node)
    {
        if(node.sym !is null)
        {
            node.sym.accept(this);
            return;
        }

        assert(false);
    }

    void visit(ASTCodegen.ClassDeclaration node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.TypeEnum node)
    {
        if(node.sym !is null)
        {
            node.sym.accept(this);
            return;
        }

        assert(false);
    }

    void visit(ASTCodegen.EnumDeclaration node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.TypeDArray node)
    {
        if(node.toString() == "string")
        {
            this.setResult(DocBasicType("string"), node);
            return;
        }

        DocArrayType doc;

        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.next.accept(typeRefVisitor);
        doc.underlyingTypeRef = new DocTypeRef();
        *doc.underlyingTypeRef = typeRefVisitor.getResult();
        
        this.setResult(doc, node);
    }

    void visit(ASTCodegen.TypeSArray node)
    {
        DocStaticArrayType doc;

        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.next.accept(typeRefVisitor);
        doc.underlyingTypeRef = new DocTypeRef();
        *doc.underlyingTypeRef = typeRefVisitor.getResult();

        scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
        node.dim.accept(expressionVisitor);
        doc.arraySizeExpression = expressionVisitor.getResult();
        
        this.setResult(doc, node);
    }

    void visit(ASTCodegen.TypeAArray node)
    {
        DocAssociativeArrayType doc;

        // Value type
        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.next.accept(typeRefVisitor);
        doc.valueTypeRef = new DocTypeRef();
        *doc.valueTypeRef = typeRefVisitor.getResult();

        // Key type
        scope typeRefVisitor2 = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.index.accept(typeRefVisitor2);
        doc.keyTypeRef = new DocTypeRef();
        *doc.keyTypeRef = typeRefVisitor2.getResult();

        this.setResult(doc, node);
    }

    void visit(ASTCodegen.TypeFunction node)
    {
        DocFunctionType doc;
    
        // Return type
        if(node.next !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.next.accept(typeRefVisitor);
            doc.returnType = new DocTypeRef();
            *doc.returnType = typeRefVisitor.getResult();
        }

        // Parameters
        if(node.parameterList.parameters !is null)
        {
            foreach(param; *node.parameterList.parameters)
            {
                scope unaryVisitor = new UnaryDefVisitor(super.context, super.moduleBeingVisited);
                param.accept(unaryVisitor);
                unaryVisitor.getResult().match!(
                    (DocRuntimeParameter p) { doc.parameters ~= p; },
                    (_){ assert(false, "Unexpected result type"); }
                );
            }
        }

        this.setResult(doc, node);
    }

    void visit(ASTCodegen.TypeDelegate node)
    {
        if(node.next !is null)
        {
            node.next.accept(this); // _Should_ be a TypeFunction
            this._result.get.raw.match!(
                (DocFunctionType ft) { ft.isDelegate = true; },
                (_){}
            );
        }
    }

    void visit(ASTCodegen.TypePointer node)
    {
        DocPointerType doc;

        // Special case: If the underlying type is a function or delegate, we remove the pointer wrapper since it makes more sense IMO.
        if(auto funcNode = node.next.isTypeFunction())
        {
            funcNode.accept(this);
            return;
        }
        else if(auto delNode = node.next.isTypeDelegate())
        {
            delNode.accept(this);
            return;
        }

        // Otherwise just get the underlying type.
        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.next.accept(typeRefVisitor);
        doc.underlyingTypeRef = new DocTypeRef();
        *doc.underlyingTypeRef = typeRefVisitor.getResult();

        this.setResult(doc, node);
    }

    void visit(ASTCodegen.TypeInstance node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.VarDeclaration node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.TypeIdentifier node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.EnumMember node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.TemplateDeclaration node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.TemplateInstance node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        node.accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }

    void visit(ASTCodegen.FuncAliasDeclaration node)
    {
        scope symbolRefVisitor = new SymbolReferenceVisitor(super.context, super.moduleBeingVisited);
        (cast(ASTCodegen.FuncDeclaration)node).accept(symbolRefVisitor);
        this.setResult(symbolRefVisitor.getResult(), node);
    }
}

final class ExpressionVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        Nullable!DocExpression _result;
    }

    mixin VisitorCommon;

    DocExpression getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    override extern(C++):

    void visit(ASTCodegen.Expression node)
    {
        import dmd.common.outbuffer : OutBuffer;
        import dmd.hdrgen           : toCBuffer, HdrGenState;
        import dmd.printast         : printAST;
        printAST(node);

        // TODO: implement a dedicated expression for
        HdrGenState state;
        state.ddoc = true;

        OutBuffer buf;
        toCBuffer(node, buf, state);

        this._result = DocExpression(DocFallbackExpression(buf.extractSlice.idup));
        super.visit(node);
    }

    void visit(ASTCodegen.IntegerExp node)
    {
        this.visit(cast(ASTCodegen.Expression)node);
    }

    void visit(ASTCodegen.StringExp node)
    {
        this.visit(cast(ASTCodegen.Expression)node);
    }

    void visit(ASTCodegen.ErrorExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.VoidInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.RealExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ComplexExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.IdentifierExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DollarExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DsymbolExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ThisExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.SuperExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.NullExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.InterpExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.TupleExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ArrayLiteralExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AssocArrayLiteralExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.StructLiteralExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CompoundLiteralExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.TypeExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ScopeExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.TemplateExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.NewExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.NewAnonClassExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.SymOffExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.VarExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.OverExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.FuncExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DeclarationExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.TypeidExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.TraitsExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.HaltExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.IsExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.MixinExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ImportExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AssertExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ThrowExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DotIdExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DotTemplateExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DotVarExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DotTemplateInstanceExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DelegateExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DotTypeExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CallExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AddrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.PtrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.NegExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.UAddExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ComExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.NotExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DeleteExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CastExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.VectorExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.VectorArrayExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.SliceExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ArrayLengthExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ArrayExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DotExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CommaExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.IntervalExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DelegatePtrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DelegateFuncptrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.IndexExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.PostExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.PreExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.LoweredAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ConstructExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.BlitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AddAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.MinAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.MulAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DivAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ModAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AndAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.OrAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.XorAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.PowAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ShlAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ShrAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.UshrAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AddExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.MinExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CatExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.MulExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DivExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ModExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.PowExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ShlExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ShrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.UshrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.AndExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.OrExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.XorExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.LogicalExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.InExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.RemoveExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.EqualExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.IdentityExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CondExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.GenericExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.FileInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.LineInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ModuleInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.FuncInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.PrettyFuncInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ObjcClassReferenceExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ClassReferenceExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.ThrownExceptionExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.DefaultInitExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CatAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CatElemAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.CatDcharAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.UnaExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.BinExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
    void visit(ASTCodegen.BinAssignExp exp) { this.visit(cast(ASTCodegen.Expression)exp); }
}

final class TemplateInstanceParameterVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        Nullable!DocTemplateInstanceParam _result;
    }

    mixin VisitorCommon;

    DocTemplateInstanceParam getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    override extern(C++):

    void visit(ASTCodegen.Type node)
    {
        scope typeVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.accept(typeVisitor);

        auto symbolRef = new DocTypeRef();
        *symbolRef = typeVisitor.getResult();
        this._result = DocTemplateInstanceParam(symbolRef);
    }

    void visit(ASTCodegen.Expression node)
    {
        scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
        node.accept(expressionVisitor);

        this._result = DocTemplateInstanceParam(expressionVisitor.getResult());
    }

    void visit(ASTCodegen.Dsymbol node)
    {
        // TODO: Handle this case
        warningf("TemplateInstanceParameterVisitor support for DSymbol nodes is TODO");
        this._result = DocTemplateInstanceParam(DocExpression(DocFallbackExpression("__MARMOS_BUG__")));
    }
}

final class TemplateParameterVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        Nullable!DocTemplateParam _result;
    }

    mixin VisitorCommon;

    DocTemplateParam getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    override extern(C++):

    void visit(ASTCodegen.TemplateTypeParameter node)
    {
        DocTemplateTypeParam doc;
        doc.name = node.ident.toString.idup;

        // Default type
        if(node.defaultType !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.defaultType.accept(typeRefVisitor);
            doc.defaultType = typeRefVisitor.getResult();
        }

        // Spec type
        if(node.specType !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.specType.accept(typeRefVisitor);
            doc.specType = typeRefVisitor.getResult();
        }

        this._result = DocTemplateParam(doc);
    }

    void visit(ASTCodegen.TemplateAliasParameter node)
    {
        import dmd.ast_node : ASTNode;

        DocTemplateAliasParam doc;
        doc.name = node.ident.toString.idup;

        // Spec type
        if(node.specType !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.specType.accept(typeRefVisitor);
            doc.specType = typeRefVisitor.getResult();
        }

        // Spec alias
        if(node.specAlias !is null)
        if(auto specAlias = cast(ASTNode)node.specAlias)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            specAlias.accept(typeRefVisitor);
            doc.specAlias = typeRefVisitor.getResult();
        }

        // Default alias
        if(node.defaultAlias !is null)
        if(auto defaultAlias = cast(ASTNode)node.defaultAlias)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            defaultAlias.accept(typeRefVisitor);
            doc.defaultAlias = typeRefVisitor.getResult();
        }

        this._result = DocTemplateParam(doc);
    }

    void visit(ASTCodegen.TemplateValueParameter node)
    {
        import dmd.ast_node : ASTNode;

        DocTemplateValueParam doc;
        doc.name = node.ident.toString.idup;

        // Value type
        if(node.valType !is null)
        {
            scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.valType.accept(typeRefVisitor);
            doc.valueType = typeRefVisitor.getResult();
        }

        // Spec value
        if(node.specValue !is null)
        {
            scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
            node.specValue.accept(expressionVisitor);
            doc.specValue = expressionVisitor.getResult();
        }

        // Default value
        if(node.defaultValue !is null)
        {
            scope expressionVisitor = new ExpressionVisitor(super.context, super.moduleBeingVisited);
            node.defaultValue.accept(expressionVisitor);
            doc.defaultValue = expressionVisitor.getResult();
        }

        this._result = DocTemplateParam(doc);
    }

    void visit(ASTCodegen.TemplateTupleParameter node)
    {
        import dmd.ast_node : ASTNode;

        DocTemplateTupleParam doc;
        doc.name = node.ident.toString.idup;

        this._result = DocTemplateParam(doc);
    }
}

final class SymbolReferenceVisitor : Visitor
{
    alias visit = Visitor.visit;

    private
    {
        DocSymbolReference _result;
        bool _parentsHandled;
    }

    mixin VisitorCommon;

    DocSymbolReference getResult()
    {
        return this._result;
    }

    // Returns `true` if the caller should immediately return, e.g. because it's the eponymous template symbol we don't want to duplicate.
    bool handleParent(Dsymbol node)
    {
        if(node.parent is null)
            return false;
        
        node.parent.accept(this);
        if(auto tiNode = node.parent.isTemplateInstance())
        {
            if(tiNode.name == node.ident) // `node` is the eponymous template symbol of its parent template instance
                return true;
        }

        return false;
    }

    override extern(C++):

    void visit(ASTCodegen.Package node)
    {
        this._result.moduleFqnComponents = fqn(node);
    }

    void visit(ASTCodegen.VarDeclaration node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(node.ident.toString.idup));
    }

    void visit(ASTCodegen.EnumMember node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(node.ident.toString.idup));
    }

    void visit(ASTCodegen.StructDeclaration node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(node.ident.toString.idup));
    }

    void visit(ASTCodegen.ClassDeclaration node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(node.ident.toString.idup));
    }

    void visit(ASTCodegen.EnumDeclaration node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(node.ident.toString.idup));
    }

    void visit(ASTCodegen.TemplateInstance node)
    {
        if(this.handleParent(node)) return;

        DocSymbolInstanceReference doc;
        doc.symbolName = node.name.toString.idup;
        
        // TODO: Try to detect how many arguments are just the default ones, and don't emit them in the output.
        // _Kinda_ wish the compiler kept the original parameter list around, or at the very least helped mark which params are just the default ones it injected.
        size_t nonDefaultItems = size_t.max;

        foreach(i, arg; *node.tiargs)
        {
            import dmd.ast_node : ASTNode;

            if(i >= nonDefaultItems)
                break;

            scope paramVisitor = new TemplateInstanceParameterVisitor(super.context, super.moduleBeingVisited);
            (cast(ASTNode)arg).accept(paramVisitor);
            doc.parameters ~= paramVisitor.getResult();
        }

        this._result.items ~= DocSymbolReferenceItem(doc);
    }

    void visit(ASTCodegen.TemplateDeclaration node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolInstanceReference(node.ident.toString.idup, null));
    }

    void visit(ASTCodegen.TypeInstance node)
    {
        /*
            When we're using semantic passes, I don't think TypeInstance tends to get used directly very much (.originalType seems to be where it mainly shows up?).

            Given `alias A = S!0.F`.

            When using semantic passes:
                * The compiler points the alias to a `VarDeclaration` (the `.a` that has `S!0.S` as a parent) that we can work backwards from easily to reconstruct the reference.
                * The alias' `originalType` is set to below.

            When NOT using semantic passes:
                * The compiler points the alias to a `TypeInstance` (the `S!0`).
                * The `.F` part is stored within the `node.idents` field, so we can't really work backwards and instead have to use different logic.
        */

        if(node.tempinst !is null)
        {
            if(this.handleParent(node.tempinst))
                return;
        }

        this.visit(cast(ASTCodegen.TypeQualified)node);
    }

    void visit(ASTCodegen.TypeIdentifier node)
    {
        // (See the TypeInstance overload, since it's the exact same case)
        this.visit(cast(ASTCodegen.TypeQualified)node);
    }

    void visit(ASTCodegen.TypeQualified node)
    {
        import dmd.identifier : Identifier;

        // TypeIdentifier ONLY stores the first identifier in its .ident field, NOT inside of .idents (lol)
        if(auto identifier = node.isTypeIdentifier())
            this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(identifier.ident.toString.idup));

        foreach(ident; node.idents)
        {
            if(auto identifier = cast(Identifier)ident)
                this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(identifier.toString.idup));
            else if(auto typeInstance = cast(ASTCodegen.TypeInstance)ident)
            {
                if(typeInstance.tempinst !is null)
                    typeInstance.accept(this);
                else
                {
                    // For now since it's simpler, let's just use toString
                    this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(typeInstance.toString.idup));
                }
            }
            else
            {
                warningf("[visit(TypeQualified)] unhandled identifier: %s", node);
                this._result.items ~= DocSymbolReferenceItem(DocSymbolUnhandled());
            }
        }
    }
}