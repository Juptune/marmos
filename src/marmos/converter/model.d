/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.model;

import std.sumtype : SumType;
import std.typecons : Nullable;

/++++ Documentation Comments ++++/

alias DocCommentBlock = SumType!(
    DocCommentParagraphBlock,
    DocCommentOrderedListBlock,
    DocCommentUnorderedListBlock,
    DocCommentEqualListBlock
);

alias DocCommentInline = SumType!(
    DocCommentTextInline,
    DocCommentBoldInline,
    DocCommentItalicInline,
    DocCommentCodeInline,
    DocCommentLinkInline
);

struct DocCommentTextInline
{
    string text;
}

struct DocCommentBoldInline
{
    string text;
}

struct DocCommentItalicInline
{
    string text;
}

struct DocCommentCodeInline
{
    string text;
}

struct DocCommentLinkInline
{
    string text;
    string url;
}

struct DocCommentParagraphBlock
{
    DocCommentInline[] inlines;
}

struct DocCommentOrderedListBlock
{
    static struct Item
    {
        DocCommentParagraphBlock block;
        int nestingLevel;
    }

    Item[] items;
}

struct DocCommentUnorderedListBlock
{
    static struct Item
    {
        DocCommentParagraphBlock block;
        bool nestingLevel;
    }

    Item[] items;
}

struct DocCommentEqualListBlock
{
    static struct Item
    {
        string key;
        DocCommentParagraphBlock value;
    }

    Item[] items;
}

struct DocCommentSection
{
    string title;
    DocCommentBlock[] blocks;
}

struct DocComment
{
    DocCommentSection[] sections;
}

/++++ Common ++++/

import dmd.astenums : LINK, STC;
import dmd.dsymbol : Visibility;
import marmos.context;

enum DocVisibility : string
{
    @(Visibility.Kind.undefined)    undefined   = "not explicitly defined",
    @(Visibility.Kind.private_)     private_    = "private",
    @(Visibility.Kind.package_)     package_    = "package",
    @(Visibility.Kind.protected_)   protected_  = "protected",
    @(Visibility.Kind.public_)      public_     = "public",
    @(Visibility.Kind.export_)      export_     = "export",
}

enum DocLinkage : string
{
    @(LINK.default_) default_ = "default",
    @(LINK.d)        d        = "extern(D)",
    @(LINK.c)        c        = "extern(C)",
    @(LINK.cpp)      cpp      = "extern(C++)",
    @(LINK.windows)  windows  = "extern(Windows)",
    @(LINK.objc)     objc     = "extern(Objective-C)",
    @(LINK.system)   system   = "extern(System)",
}

enum DocStorageClass : string
{
    FAILSAFE = "This should never be seen",

    @(STC.static_)              static_             = "static",
    @(STC.extern_)              extern_             = "extern",
    @(STC.const_)               const_              = "const",
    @(STC.final_)               final_              = "final",
    @(STC.abstract_)            abstract_           = "abastract",
    @(STC.override_)            override_           = "override",
    @(STC.auto_)                auto_               = "auto",
    @(STC.synchronized_)        synchronized_       = "synchronized",
    @(STC.deprecated_)          deprecated_         = "deprecated",
    @(STC.in_)                  in_                 = "in",
    @(STC.out_)                 out_                = "out",
    @(STC.lazy_)                lazy_               = "lazy",
    @(STC.variadic)             variadic            = "...",
    @(STC.ref_)                 ref_                = "ref",
    @(STC.scope_)               scope_              = "scope",
    @(STC.return_)              return_             = "return",
    @(STC.returnScope)          returnScope         = "return scope",
    @(STC.returnRef)            returnRef           = "return ref",
    @(STC.immutable_)           immutable_          = "immutable",
    @(STC.nothrow_)             nothrow_            = "nothrow",
    @(STC.pure_)                pure_               = "pure",
    @(STC.alias_)               alias_              = "alias",
    @(STC.shared_)              shared_             = "shared",
    @(STC.gshared)              gshared             = "__gshared",
    @(STC.property)             property            = "@property",
    @(STC.safe)                 safe                = "@safe",
    @(STC.trusted)              trusted             = "@trusted",
    @(STC.system)               system              = "@system",
    @(STC.nogc)                 nogc                = "@nogc",
    @(STC.autoref)              autoref             = "auto ref",
    @(STC.live)                 live                = "@live",
}

enum DocFeatures
{
    FAILSAFE = "This should never be seen",

    @(MarmosContext.Features.semanticPass) semanticPass = "semanticPass",
}

/++++ Definitions ++++/

alias DocAggregateDef = SumType!(
    DocStruct,
    DocClass,
    DocUnion,
);

alias DocUnaryDef = SumType!(
    DocVariable,
    DocFunction,
    DocRuntimeParameter,
    DocAlias,
);

alias DocUda = SumType!(
    DocValueUda,
    DocSymbolUda,
);

alias DocTypeRef = SumType!(
    DocSymbolReference,
    DocArrayType,
    DocAssociativeArrayType,
    DocTemplateInstance,
    DocFunctionType,
    DocBasicType,
);

alias DocTemplateInstanceParam = SumType!(
    DocExpression,
    DocSymbolReference,
);

private mixin template DocCommon()
{
    string              name;
    DocComment          comment;
    DocLinkage          linkage;
    ulong               line;
    DocVisibility       visibility;
    DocStorageClass[]   storageClasses;
    DocUda[]            udas;
}

private mixin template DocAggregateCommon()
{
    DocAggregateDef[] nestedTypes;
    DocUnaryDef[] members;
}

struct DocModelRoot
{
    DocFeatures[] features;
    DocModule module_;
}

struct DocModule
{
    string[] fqnComponents;
    DocComment comment;
    mixin DocAggregateCommon;
}

/++ Aggregates ++/

struct DocClass
{
    mixin DocCommon;
    mixin DocAggregateCommon;

    Nullable!DocTypeRef baseClass;
    DocTypeRef[] interfaces;
}

struct DocStruct
{
    mixin DocCommon;
    mixin DocAggregateCommon;
}

struct DocInterface
{
    mixin DocCommon;
    mixin DocAggregateCommon;
}

struct DocEnum
{
    mixin DocCommon;
    mixin DocAggregateCommon;

    Nullable!DocSymbolReference baseTypeRef;
}

struct DocUnion
{
    mixin DocCommon;
    mixin DocAggregateCommon;
}

/++ Unary ++/

struct DocAlias
{
    mixin DocCommon;

    DocTypeRef symbolRef;
}

struct DocVariable
{
    mixin DocCommon;

    DocTypeRef typeRef;
    Nullable!DocExpression defaultValueExpression;
}

struct DocRuntimeParameter
{
    string                  name;
    ulong                   line;
    DocStorageClass[]       storageClasses;
    DocUda[]                udas;

    DocTypeRef              typeRef;
    Nullable!DocExpression  defaultValueExpression;
}

struct DocFunction
{
    mixin DocCommon;

    DocFunctionType funcType;
}

/++ Types ++/

struct DocFunctionType
{
    DocRuntimeParameter[] parameters;
    DocTypeRef* returnType; // Needs to be a pointer due to circular type references - this will be GC allocated
}

struct DocArrayType
{
    DocTypeRef* underlyingTypeRef; // Needs to be a pointer due to circular type references - this will be GC allocated
}

struct DocAssociativeArrayType
{
    DocTypeRef* underlyingTypeRef;  // Needs to be a pointer due to circular type references - this will be GC allocated
}

struct DocSymbolReference
{
    string[] fqnComponents;
}

struct DocBasicType
{
    string name;
}

struct DocTemplateInstance
{
    DocSymbolReference templateRef;
    DocTemplateInstanceParam[] parameters;
}

/++ Other ++/

struct DocSymbolUda
{
    DocSymbolReference reference;
}

struct DocExpression
{
    string renderedCode;
}

struct DocValueUda
{
    DocExpression expression;
}