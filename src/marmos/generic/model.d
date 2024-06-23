/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.generic.model;

import std.sumtype  : SumType;
import std.file     : getcwd;
import dmd.astenums : Edition, STC, LINK;
import dmd.dsymbol  : Visibility;

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
        bool isNested;
    }

    Item[] items;
}

struct DocCommentUnorderedListBlock
{
    static struct Item
    {
        DocCommentParagraphBlock block;
        bool isNested;
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

struct DocPath
{
    string path;
    string basePath;
}

struct DocLocation
{
    import dmd.location : Loc;

    DocPath path;
    uint line;
    uint column;

    static DocLocation from(scope const Loc loc, string basePath = getcwd)
    {
        import std.string : fromStringz;

        DocLocation result;
        result.line = loc.linnum;
        result.column = loc.charnum;

        version(MesonTest) {}
        else result.path = DocPath(loc.filename.fromStringz.idup, basePath);
        return result;
    }
}

enum DocStorageClass : string
{
    @(STC.undefined_)   FAILSAFE            = "This should never be seen",
    @(STC.static_)      static_             = "static",
    @(STC.extern_)      extern_             = "extern",
    @(STC.const_)       const_              = "const",
    @(STC.final_)       final_              = "final",
    @(STC.abstract_)    abstract_           = "abstract",
    @(STC.override_)    override_           = "override",
    @(STC.auto_)        auto_               = "auto",
    @(STC.synchronized_)synchronized_       = "synchronized",
    @(STC.deprecated_)  deprecated_         = "deprecated",
    @(STC.in_)          in_                 = "in",
    @(STC.out_)         out_                = "out",
    @(STC.lazy_)        lazy_               = "lazy",
    @(STC.variadic)     variadic            = "variadic",
    @(STC.ref_)         ref_                = "ref",
    @(STC.scope_)       scope_              = "scope",
    @(STC.return_)      return_             = "return ref",
    @(STC.returnScope)  returnScope         = "ref return scope",
    @(STC.immutable_)   immutable_          = "immutable",
    @(STC.nothrow_)     nothrow_            = "nothrow",
    @(STC.pure_)        pure_               = "pure",
    @(STC.alias_)       alias_              = "alias",
    @(STC.shared_)      shared_             = "shared",
    @(STC.gshared)      gshared             = "__gshared",
    @(STC.property)     property            = "@property",
    @(STC.safe)         safe                = "@safe",
    @(STC.trusted)      trusted             = "@trusted",
    @(STC.system)       system              = "@system",
    @(STC.disable)      disable             = "@disable",
    @(STC.nogc)         nogc                = "@nogc",
    @(STC.autoref)      autoref             = "auto ref",
    @(STC.live)         live                = "@live",
}

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
    @(LINK.d)       d       = "extern(D)",
    @(LINK.c)       c       = "extern(C)",
    @(LINK.cpp)     cpp     = "extern(C++)",
    @(LINK.windows) windows = "extern(Windows)",
    @(LINK.objc)    objc    = "extern(Objective-C)",
    @(LINK.system)  system  = "extern(System)",
}

/++++ Definitions ++++/

alias DocAggregateType = SumType!(
    DocStruct,
    DocClass,
    DocInterface,
    DocUnion,
    DocTemplate,
    DocMixinTemplate,
    DocEnum,
);

alias DocSoloType = SumType!(
    DocAlias,
    DocFunction,
    DocVariable
);

struct DocModule
{
    import dmd.dmodule : Module;

    string[]            nameComponents; // ["abc", "def"] -> abc.def
    bool                isPackageFile;  // For package.d files
    Edition             languageEdition;
    DocComment          comment;
    DocLocation         location;
    DocAggregateType[]  types;
    DocSoloType[]       soloTypes;
}

private mixin template DocCommon()
{
    string              name;
    DocComment          comment;
    DocLinkage          linkage;
    DocLocation         location;
    DocVisibility       visibility;
    DocStorageClass[]   storageClasses;
}

private mixin template DocTypeCommon()
{
    DocAggregateType[] nestedTypes;
    DocSoloType[] members;
}

struct DocStruct
{
    mixin DocCommon;
    mixin DocTypeCommon;
}

struct DocClass
{
    mixin DocCommon;
    mixin DocTypeCommon;
}

struct DocInterface
{
    mixin DocCommon;
    mixin DocTypeCommon;
}

struct DocUnion
{
    mixin DocCommon;
    mixin DocTypeCommon;
}

struct DocTemplate
{
    mixin DocCommon;
    mixin DocTypeCommon;
    bool isEponymous;
}

struct DocMixinTemplate
{
    mixin DocCommon;
    mixin DocTypeCommon;
}

struct DocEnum
{
    mixin DocCommon;
    mixin DocTypeCommon;
}

struct DocAlias
{
    mixin DocCommon;
}

struct DocFunction
{
    mixin DocCommon;
    DocRuntimeParameter[] parameters;
}

struct DocVariable
{
    mixin DocCommon;
    DocTypeReference type;
}

struct DocTypeReference
{
    string[] nameComponents;
}

struct DocRuntimeParameter
{
    string name;
    DocTypeReference type;
}