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
        typeRefVisitor.getResult().match!(
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
        node.type.accept(typeRefVisitor);
        doc.symbolRef = typeRefVisitor.getResult();

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

    DocTypeRef getResult()
    in(!this._result.isNull, "result is null, was visit called?")
    {
        return this._result.get;
    }

    override extern(C++):

    void visit(ASTCodegen.TypeBasic node)
    {
        this._result = DocTypeRef(DocBasicType(node.toString().idup));
    }

    void visit(ASTCodegen.TypeStruct node)
    {
        this._result = DocTypeRef(DocSymbolReference(fqn(node.sym)));
    }

    void visit(ASTCodegen.TypeClass node)
    {
        this._result = DocTypeRef(DocSymbolReference(fqn(node.sym)));
    }

    void visit(ASTCodegen.TypeEnum node)
    {
        this._result = DocTypeRef(DocSymbolReference(fqn(node.sym)));
    }

    void visit(ASTCodegen.TypeDArray node)
    {
        if(node.toString() == "string")
        {
            this._result = DocTypeRef(DocBasicType("string"));
            return;
        }

        DocArrayType doc;

        scope typeRefVisitor = new TypeRefVisitor(super.context, super.moduleBeingVisited);
        node.next.accept(typeRefVisitor);
        doc.underlyingTypeRef = new DocTypeRef();
        *doc.underlyingTypeRef = typeRefVisitor.getResult();
        
        this._result = DocTypeRef(doc);
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

        this._result = DocTypeRef(doc);
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