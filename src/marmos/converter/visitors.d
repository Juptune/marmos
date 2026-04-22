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
        MarmosContext context;
        Module moduleBeingVisited;

        this(string typeName, MarmosContext context, Module mod)
        {
            this._typeName = typeName;
            this.context = context;
            this.moduleBeingVisited = mod;
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
    this(MarmosContext context, Module mod)
    {
        super(typeof(this).stringof, context, mod);
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
        scope visitor = new AggregateDefVisitor(super.context, super.moduleBeingVisited);
        node.accept(visitor);
        this.aggregateDefinitions ~= visitor.getResult();
    }

    private void visitUnary(NodeT)(NodeT node)
    {
        scope visitor = new UnaryDefVisitor(super.context, super.moduleBeingVisited);
        node.accept(visitor);
        this.unaryDefinitions ~= visitor.getResult();
    }

    override extern(C++):
    
    void visit(ASTCodegen.ClassDeclaration node) => visitAggregate(node);
    void visit(ASTCodegen.FuncDeclaration node) => visitUnary(node);
    void visit(ASTCodegen.AliasDeclaration node) => visitUnary(node);

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

    void visit(ASTCodegen.Import){}
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

    override extern(C++):
    
    void visit(ASTCodegen.ClassDeclaration node)
    {
        import marmos.converter.common : isBaseObject;

        DocClass doc;
        extractCommonInfo(doc, node);

        // Interfaces & base class
        if(node.baseClass !is null && !isBaseObject(node.baseClass, super.context))
        {
            import dmd.dsymbol;
            Dsymbol p = node.baseClass;
            while(p)
            {
                import std;
                writeln(p);
                p = p.parent;
            }

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

        // Other
        if(node.stack)
            doc.storageClasses ~= DocStorageClass.scope_;
        if(node.isabstract == ThreeState.yes)
            doc.storageClasses ~= DocStorageClass.abstract_;

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
        extractCommonInfo(doc, node);

        // Underlying function type
        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.type.accept(typeRefVisitor);
        typeRefVisitor.getResult().raw.match!(
            (DocFunctionType ft) { doc.funcType = ft; },
            (_){ assert(false, "Unexpected result type"); }
        );

        this._result = DocUnaryDef(doc);
    }

    void visit(ASTCodegen.Parameter node)
    {
        DocRuntimeParameter doc;
        extractCommonInfo(doc, node);

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
        extractCommonInfo(doc, node);

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
            scope originalTypeVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
            node.originalType.accept(originalTypeVisitor);
            doc.symbolRef.originalTypeRaw = new DocTypeRefRaw();
            *doc.symbolRef.originalTypeRaw.get = originalTypeVisitor.getResult().raw;
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

    // void visit(ASTCodegen.TypeStruct node)
    // {
    //     const fqnComponents = fqn(node.sym);
    //     this.setResult(DocSymbolReference(fqnComponents[0..$-1], DocSymbolDirectReference(fqnComponents[$-1])), node);
    // }

    // void visit(ASTCodegen.TypeClass node)
    // {
    //     const fqnComponents = fqn(node.sym);
    //     this.setResult(DocSymbolReference(fqnComponents[0..$-1], DocSymbolDirectReference(fqnComponents[$-1])), node);
    // }

    // void visit(ASTCodegen.TypeEnum node)
    // {
    //     const fqnComponents = fqn(node.sym);
    //     this.setResult(DocSymbolReference(fqnComponents[0..$-1], DocSymbolDirectReference(fqnComponents[$-1])), node);
    // }

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
        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.next.accept(typeRefVisitor);
        doc.returnType = new DocTypeRef();
        *doc.returnType = typeRefVisitor.getResult();

        // Parameters
        foreach(param; *node.parameterList.parameters)
        {
            scope unaryVisitor = new UnaryDefVisitor(super.context, super.moduleBeingVisited);
            param.accept(unaryVisitor);
            unaryVisitor.getResult().match!(
                (DocRuntimeParameter p) { doc.parameters ~= p; },
                (_){ assert(false, "Unexpected result type"); }
            );
        }

        this.setResult(doc, node);
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
        import dmd.printast : printAST;
        printAST(node);

        // TODO: implement
        super.visit(node);
    }
}

final class TemplateParameterVisitor : Visitor
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

    void visit(ASTCodegen.StructDeclaration node)
    {
        if(this.handleParent(node)) return;
        this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(node.ident.toString.idup));
    }

    void visit(ASTCodegen.TemplateInstance node)
    {
        if(this.handleParent(node)) return;

        DocSymbolInstanceReference doc;
        doc.symbolName = node.name.toString.idup;
        
        foreach(arg; *node.tiargs)
        {
            import dmd.ast_node : ASTNode;

            scope paramVisitor = new TemplateParameterVisitor(super.context, super.moduleBeingVisited);
            (cast(ASTNode)arg).accept(paramVisitor);
            doc.parameters ~= paramVisitor.getResult();
        }

        this._result.items ~= DocSymbolReferenceItem(doc);
    }

    void visit(ASTCodegen.TypeInstance node)
    {
        /*
            When we're using semantic passes, I don't think TypeInstance tends to get used directly very much.

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
                warningf("[visit(TypeQualified)] unhandled identifier: %s", node);
        }

        // TypeIdentifier ONLY stores the final identifier in its .ident field, NOT inside of .idents (lol)
        if(auto identifier = node.isTypeIdentifier())
            this._result.items ~= DocSymbolReferenceItem(DocSymbolDirectReference(identifier.ident.toString.idup));
    }
}