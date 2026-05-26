/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */

module marmos.docs.staging_generator;

import std.algorithm : map;
import std.array     : array;
import std.logger    : infof;
import std.typecons  : Nullable;

import marmos.converter.model; // Intentionally everything

import marmos.docs.discover : SiteRoot, RootGroup, MarmosDocModelRootGroup;
import marmos.docs.staging_models;

void generateAndEmitGroupStagingFiles(SiteRoot site, RootGroup group)
{
    import marmos.docs.discover : loadJsonModel;

    if(auto casted = cast(MarmosDocModelRootGroup)group)
    {
        SymbolTree!DocModelRoot[] moduleTrees;

        // Load each module that's part of the API group (TODO: I think eventually there needs to be a pathway for incrementally building up some of this stuff, since large codebases are going to OOM?)
        foreach(filePath; casted.modelFilePaths)
        {
            auto model = loadJsonModel!DocModelRoot(filePath);
            auto tree = SymbolTree!DocModelRoot.fromModel(model.module_, model);
            moduleTrees ~= tree;
        }

        // Build & emit things that can be done in one go.
        auto navRoot = GroupNavRoot.init; // Omitted for reduced sample
        foreach(moduleTree; moduleTrees)
            buildAndEmitChildPages(group, site, moduleTree, navRoot);
    }
    else
        infof("TODO: Unhandled root group %s", group);
}

/++ Private generators ++/

private void buildAndEmitChildPages(DocModelT)(
    RootGroup group,
    SiteRoot site,
    SymbolTree!DocModelT tree,
    scope ref GroupNavRoot nav,
    bool hideNavItem = false,
)
{
    LeafT[] findOverrides(LeafT)(LeafT mainLeaf, LeafT[] otherLeaves, scope ref size_t i)
    {
        // Omitted for reduced sample
        return [mainLeaf];
    }

    // NOTE: _Technically_ aggregate types can also have multiple definitions due to conditional compliation... but TODO: for now the last one wins.
    foreach(item; tree.classes) buildAndEmitAggregatePage!"Classes"(group, site, item, nav, hideNavItem);
    foreach(item; tree.structs) buildAndEmitAggregatePage!"Structs"(group, site, item, nav, hideNavItem);
    foreach(item; tree.unions) buildAndEmitAggregatePage!"Unions"(group, site, item, nav, hideNavItem);
    foreach(item; tree.templates) buildAndEmitAggregatePage!"Templates"(group, site, item, nav, hideNavItem);
    for(size_t i = 0; i < tree.aliases.length; i++) 
    {
        auto item = tree.aliases[i];
        auto overrides = findOverrides(item, tree.aliases, i); // Modifies `i`
        buildAndEmitLeafPage!"Aliases"(group, site, item, overrides, nav, hideNavItem);
    }
    for(size_t i = 0; i < tree.functions.length; i++) 
    {
        auto item = tree.functions[i];
        auto overrides = findOverrides(item, tree.functions, i); // Modifies `i`
        buildAndEmitLeafPage!"Functions"(group, site, item, overrides, nav, hideNavItem);
    }
    for(size_t i = 0; i < tree.constants.length; i++) 
    {
        auto item = tree.constants[i];
        auto overrides = findOverrides(item, tree.constants, i); // Modifies `i`
        buildAndEmitLeafPage!"Constants"(group, site, item, overrides, nav, hideNavItem);
    }
    for(size_t i = 0; i < tree.enums.length; i++) 
    {
        auto item = tree.enums[i];
        auto overrides = findOverrides(item, tree.enums, i); // Modifies `i`
        buildAndEmitLeafPage!"Enums"(group, site, item, overrides, nav, hideNavItem);
    }
    for(size_t i = 0; i < tree.variables.length; i++) 
    {
        auto item = tree.variables[i];
        auto overrides = findOverrides(item, tree.variables, i); // Modifies `i`
        buildAndEmitLeafPage!"Variables"(group, site, item, overrides, nav, hideNavItem);
    }
}

private void buildAndEmitAggregatePage(string TypeName, DocModelT)(
    RootGroup group,
    SiteRoot site,
    SymbolTree!DocModelT tree,
    scope ref GroupNavRoot nav,
    bool hideNavItem = false,
)
{
    import std.string : join;

    ApiPageRoot page;

    page.add(buildDlangCodeBlock(site, tree));

    // Generate pages for nested types.
    buildAndEmitChildPages(group, site, tree, nav, hideNavItem: true);
}

private void buildAndEmitLeafPage(string TypeName, DocModelT)(
    RootGroup group,
    SiteRoot site,
    SymbolLeaf!DocModelT leaf,
    SymbolLeaf!DocModelT[] overrides,
    scope ref GroupNavRoot nav,
    bool hideNavItem = false,
)
{
    import std.conv   : to;
    import std.string : join;

    static if(is(typeof(leaf.model) : MaybeTemplated!Underlying, Underlying))
        auto model = leaf.model.model;
    else
        auto model = leaf.model;

    ApiPageRoot page;

    // NOTE: I can't get the crash to happen without these lines
    page.add(buildDlangCodeBlock(site, leaf));
    const indexFileHref = __traits(getMember, site, "groupModule"~TypeName~"IndexHref")(group.groupUrlName, leaf.module_, leaf.memberComponents, "latest");
    auto  indexIdPath   = __traits(getMember, site, "groupNav"~TypeName~"IdPath")(leaf.module_, leaf.memberComponents);
    nav.getOrMakeByIdPath(indexIdPath, isGroup: false, isHidden: hideNavItem).href = indexFileHref;
    nav.getOrMakeByIdPathHidden(leaf.module_.fqnComponents ~ leaf.memberComponents).href = indexFileHref;
}

/++ Doc comment converters ++/

private ApiPageComponent[] convertDocComment(Nullable!DocComment comment, scope ref ApiPageRoot.SidebarHeader[] sidebarHeaders)
    => comment.isNull ? [] : convertDocComment(comment.get, sidebarHeaders);

private ApiPageComponent[] convertDocComment(DocComment comment, scope ref ApiPageRoot.SidebarHeader[] sidebarHeaders)
{
    import std.sumtype : match;

    ApiPageComponent[] result;

    void convertParagraph(DocCommentParagraphBlock block, scope ref ApiPageComponent[] components)
    {
        // NOTE: Strangely all of these lines are needed, I can't really reduce it.
        ApiPageParagraph paragraph;
        foreach(sumType; block.inlines)
        {
            paragraph.components ~= sumType.match!(
                (DocCommentTextInline inline) => ApiPageSpan(text: inline.text).asComponent,
                (DocCommentBoldInline inline) => ApiPageSpan(text: inline.text, style: [ApiPageSpan.Style.bold]).asComponent,
                (DocCommentItalicInline inline) => ApiPageSpan(text: inline.text, style: [ApiPageSpan.Style.italic]).asComponent,
                (DocCommentCodeInline inline) => ApiPageSpan(text: inline.text, style: [ApiPageSpan.Style.code]).asComponent,
                (DocCommentLinkInline inline) => ApiPageSpan(text: inline.text).asHrefLink(inline.url),
            );
        }
        components ~= paragraph.asComponent;
    }

    auto docHeader = ApiPageHeader();
    sidebarHeaders ~= ApiPageRoot.SidebarHeader();
    result ~= docHeader.asComponent;

    foreach(section; comment.sections)
    {
        if(section.title != "__default")
        {
            auto header = ApiPageHeader(level: 3, htmlId: section.title, section.title); // TODO: Make sure the ID is converted into something URL friendly
            sidebarHeaders ~= ApiPageRoot.SidebarHeader(header.htmlId, header.text, nestingLevel: 1);
            result ~= header.asComponent;
        }

        foreach(sumType; section.blocks)
        {
            sumType.match!(
                (DocCommentParagraphBlock block) {
                    convertParagraph(block, result);
                },
                (DocCommentOrderedListBlock block) {
                    // omitted
                },
                (DocCommentUnorderedListBlock block) {
                    // omitted
                },
                (DocCommentEqualListBlock block) {
                    // TODO
                },
            );
        }
    }

    return result;
}

private ApiPageDlangCodeComponent getOverviewCommentForCode(DocCommentT)(DocCommentT comment)
{
    ApiPageRoot.SidebarHeader[] fakeSidebar;
    auto components = convertDocComment(comment, fakeSidebar);
    return ApiPageCodeText(ApiPageCodeText.Syntax.comment, "/// TODO").asCodeComponent;
}

/++ Code block generation ++/

private immutable STORAGE_CLASSES_BEFORE_FUNCTION_NAME = [
    DocStorageClass.abstract_,
    DocStorageClass.auto_,
    DocStorageClass.autoref,
    DocStorageClass.final_,
    DocStorageClass.override_,
    DocStorageClass.shared_,
    DocStorageClass.static_,
    DocStorageClass.synchronized_,
];

private ApiPageDlangCode buildDlangCodeBlock(TreeOrLeafT)(SiteRoot site, TreeOrLeafT treeOrLeaf)
{
    ApiPageDlangCode code;
    appendCode(site, treeOrLeaf, code);

    return code;
}

private void appendCode(SiteRoot site, SymbolTree!(MaybeTemplated!DocClass) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocClass model = doc.model.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendLinkage(model.linkage, code);
    appendVisibility(model.visibility, code);
    appendAggregateStorageClasses(model.storageClasses, code);
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "class "));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, doc.memberComponents[$-1]).asNavLink(
        site.groupNavClassesIdPath(doc.module_, doc.memberComponents)
    ));

    if(!doc.model.eponymousTemplate.isNull)
    {
        auto tpl = doc.model.eponymousTemplate.get;
        appendTemplateParams(tpl.originalParameters.length > 0 ? tpl.originalParameters : tpl.parameters, code, forceSingleLine: isNestedOverview);
    }

    if(!model.baseClass.isNull || model.interfaces.length > 0)
    {
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " : "));

        if(!model.baseClass.isNull)
            appendTypeRef(model.baseClass.get, code, forceSingleLine: isNestedOverview);

        foreach(i, inter; model.interfaces)
        {
            if(i > 0 || !model.baseClass.isNull)
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ", "));

            appendTypeRef(inter, code, forceSingleLine: isNestedOverview);
        }
    }

    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "{"));
    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeIndent());

    appendSymbolTreeMembersGeneric(site, doc, code, isNestedOverview: true);

    code.add(ApiPageCodeDedent());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "}"));
}

private void appendCode(SiteRoot site, SymbolTree!(MaybeTemplated!DocStruct) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocStruct model = doc.model.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendLinkage(model.linkage, code);
    appendVisibility(model.visibility, code);
    appendAggregateStorageClasses(model.storageClasses, code);
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "struct "));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, doc.memberComponents[$-1]).asNavLink(
        site.groupNavStructsIdPath(doc.module_, doc.memberComponents)
    ));

    if(!doc.model.eponymousTemplate.isNull)
    {
        auto tpl = doc.model.eponymousTemplate.get;
        appendTemplateParams(tpl.originalParameters.length > 0 ? tpl.originalParameters : tpl.parameters, code, forceSingleLine: isNestedOverview);
    }

    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "{"));
    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeIndent());

    appendSymbolTreeMembersGeneric(site, doc, code, isNestedOverview: true);

    code.add(ApiPageCodeDedent());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "}"));
}

private void appendCode(SiteRoot site, SymbolTree!(MaybeTemplated!DocUnion) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
}

private void appendCode(SiteRoot site, SymbolTree!DocTemplate doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocTemplate model = doc.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendLinkage(model.linkage, code);
    appendVisibility(model.visibility, code);
    appendAggregateStorageClasses(model.storageClasses, code);
    if(model.isMixin)
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "mixin "));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "template "));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, doc.memberComponents[$-1]).asNavLink(
        site.groupNavTemplatesIdPath(doc.module_, doc.memberComponents)
    ));

    appendTemplateParams(model.originalParameters.length > 0 ? model.originalParameters : model.parameters, code, forceSingleLine: isNestedOverview);

    if(doc.directChildCount == 0)
    {
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "{}"));
        return;
    }

    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "{"));
    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeIndent());

    appendSymbolTreeMembersGeneric(site, doc, code, isNestedOverview: true);

    code.add(ApiPageCodeDedent());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "}"));
}

private void appendCode(SiteRoot site, SymbolLeaf!(MaybeTemplated!DocAlias) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocAlias model = doc.model.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendLinkage(model.linkage, code);
    appendVisibility(model.visibility, code);
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "alias "));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, doc.memberComponents[$-1]).asNavLink(
        site.groupNavAliasesIdPath(doc.module_, doc.memberComponents)
    ));

    if(!doc.model.eponymousTemplate.isNull)
    {
        auto tpl = doc.model.eponymousTemplate.get;
        appendTemplateParams(tpl.originalParameters.length > 0 ? tpl.originalParameters : tpl.parameters, code, forceSingleLine: isNestedOverview);
    }

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
    appendTypeRef(model.symbolRef, code, forceSingleLine: isNestedOverview);
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ";"));
}

private void appendCode(SiteRoot site, SymbolLeaf!(MaybeTemplated!DocFunction) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    import std.algorithm : filter, canFind;

    DocFunction model = doc.model.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendLinkage(model.linkage, code);
    appendVisibility(model.visibility, code);

    foreach(class_; model.storageClasses.filter!(sc => STORAGE_CLASSES_BEFORE_FUNCTION_NAME.canFind(sc)))
    {
        if(class_ == DocStorageClass.auto_) // This is handled by the type ref rather than via storage classes
            continue;
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, (cast(string)class_) ~ " "));
    }

    if(model.funcType.returnType !is null)
        appendTypeRef(*model.funcType.returnType, code, forceSingleLine: isNestedOverview);
    else
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "auto"));

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, " "~doc.memberComponents[$-1]).asNavLink(
        site.groupNavFunctionsIdPath(doc.module_, doc.memberComponents)
    ));

    if(!doc.model.eponymousTemplate.isNull)
    {
        auto tpl = doc.model.eponymousTemplate.get;
        appendTemplateParams(tpl.originalParameters.length > 0 ? tpl.originalParameters : tpl.parameters, code, forceSingleLine: isNestedOverview);
    }

    appendRuntimeParams(model.funcType.parameters, code, forceSingleLine: isNestedOverview);
    foreach(class_; model.storageClasses.filter!(sc => !STORAGE_CLASSES_BEFORE_FUNCTION_NAME.canFind(sc)))
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, (cast(string)class_) ~ " "));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ";"));
}

private void appendCode(SiteRoot site, SymbolLeaf!(MaybeTemplated!DocManifestConstant) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocManifestConstant model = doc.model.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendVisibility(model.visibility, code);
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "enum "));

    if(!model.typeRef.isNull)
        appendTypeRef(model.typeRef.get, code, forceSingleLine: isNestedOverview);

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, " "~doc.memberComponents[$-1]).asNavLink(
        site.groupNavConstantsIdPath(doc.module_, doc.memberComponents)
    ));

    if(!doc.model.eponymousTemplate.isNull)
    {
        auto tpl = doc.model.eponymousTemplate.get;
        appendTemplateParams(tpl.originalParameters.length > 0 ? tpl.originalParameters : tpl.parameters, code, forceSingleLine: isNestedOverview);
    }

    // TODO: Maybe try to figure out when to use originalValueExpression instead
    if(!model.valueExpression.isNull)
    {
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
        appendExpression(model.valueExpression.get, code, forceSingleLine: isNestedOverview);
    }

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ";"));
}

private void appendCode(SiteRoot site, SymbolLeaf!DocEnum doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    import std.sumtype : match;

    DocEnum model = doc.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendVisibility(model.visibility, code);
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "enum "));

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, doc.memberComponents[$-1]).asNavLink(
        site.groupNavEnumsIdPath(doc.module_, doc.memberComponents)
    ));

    if(!model.baseTypeRef.isNull)
    {
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " : "));
        appendTypeRef(model.baseTypeRef.get, code, forceSingleLine: isNestedOverview);
    }

    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "{"));
    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeIndent());

    foreach(i, member; model.members)
    {
        DocManifestConstant manifestConstant = member.match!(
            (DocManifestConstant c) => c,
            (_) {
                assert(false, "bug: Can this be anything other than DocManifestConstant?");
                return DocManifestConstant.init;
            },
        );

        if(i > 0)
        {
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ", "));
            code.add(ApiPageCodeNewLine());
        }

        code.add(getOverviewCommentForCode(manifestConstant.comment));
        code.add(ApiPageCodeNewLine());
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, manifestConstant.name));

        if(!manifestConstant.valueExpression.isNull)
        {
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
            appendExpression(manifestConstant.valueExpression.get, code, forceSingleLine: true);
        }
    }

    code.add(ApiPageCodeDedent());
    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "}"));
}

private void appendCode(SiteRoot site, SymbolLeaf!DocVariable doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocVariable model = doc.model;

    if(!isNestedOverview)
        appendModuleStatement(site, doc.module_, code);

    appendLinkage(model.linkage, code);
    appendVisibility(model.visibility, code);
    appendAggregateStorageClasses(model.storageClasses, code);

    if(!model.typeRef.isNull)
        appendTypeRef(model.typeRef.get, code, forceSingleLine: isNestedOverview);
    else
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "auto"));

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, " "~doc.memberComponents[$-1]).asNavLink(
        site.groupNavVariablesIdPath(doc.module_, doc.memberComponents)
    ));

    if(!model.defaultValueExpression.isNull)
    {
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
        appendExpression(model.defaultValueExpression.get, code, forceSingleLine: isNestedOverview);
    }

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ";"));
}

private void appendRuntimeParams(DocRuntimeParameter[] params, scope ref ApiPageDlangCode code, bool forceSingleLine)
{
    import std.sumtype : match;

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "("));
    if(!forceSingleLine)
    {
        code.add(ApiPageCodeNewLine());
        code.add(ApiPageCodeIndent());
    }

    foreach(i, param; params)
    {
        if(i > 0)
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ", "));

        foreach(class_; param.storageClasses)
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, (cast(string)class_) ~ " "));

        appendTypeRef(param.typeRef, code, forceSingleLine);
        if(param.name != "__anonymous")
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.none, " "~param.name));

        if(!param.defaultValueExpression.isNull)
        {
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
            appendExpression(param.defaultValueExpression.get, code, forceSingleLine);
        }
    }

    if(!forceSingleLine)
    {
        code.add(ApiPageCodeNewLine());
        code.add(ApiPageCodeDedent());
    }
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ")"));
}

private void appendTemplateParams(DocTemplateParam[] params, scope ref ApiPageDlangCode code, bool forceSingleLine)
{
    import std.sumtype : match;

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "("));
    if(!forceSingleLine)
    {
        code.add(ApiPageCodeNewLine());
        code.add(ApiPageCodeIndent());
    }

    foreach(i, sumType; params)
    {
        if(i > 0)
        {
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ", "));

            if(!forceSingleLine)
                code.add(ApiPageCodeNewLine());
        }

        sumType.match!(
            (DocTemplateValueParam param){
                if(!param.valueType.isNull)
                {
                    appendTypeRef(param.valueType.get, code, forceSingleLine);
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.none, " "));
                }

                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, param.name));

                if(!param.specValue.isNull)
                {
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " : "));
                    appendExpression(param.specValue.get, code, forceSingleLine);
                }

                if(!param.defaultValue.isNull)
                {
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
                    appendExpression(param.defaultValue.get, code, forceSingleLine);
                }
            },
            (DocTemplateTypeParam param){
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, param.name));

                if(!param.specType.isNull)
                {
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " : "));
                    appendTypeRef(param.specType.get, code, forceSingleLine);
                }

                if(!param.defaultType.isNull)
                {
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
                    appendTypeRef(param.defaultType.get, code, forceSingleLine);
                }
            },
            (DocTemplateAliasParam param){
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "alias "));

                if(!param.specType.isNull)
                {
                    appendTypeRef(param.specType.get, code, forceSingleLine);
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.none, " "));
                }

                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, param.name));

                if(!param.specAlias.isNull)
                {
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " : "));
                    appendTypeRef(param.specAlias.get, code, forceSingleLine);
                }

                if(!param.defaultAlias.isNull)
                {
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " = "));
                    appendTypeRef(param.defaultAlias.get, code, forceSingleLine);
                }
            },
            (DocTemplateTupleParam param){
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.symbol, param.name));
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.none, "..."));
            },
        );
    }

    if(!forceSingleLine)
    {
        code.add(ApiPageCodeNewLine());
        code.add(ApiPageCodeDedent());
    }
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ")"));
}

private void appendSymbolTreeMembersGeneric(DocModelT)(SiteRoot site, SymbolTree!DocModelT doc, scope ref ApiPageDlangCode code, bool isNestedOverview)
{
    bool needsNewLine = false;

    foreach(i, item; doc.classes)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.structs)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.unions)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.templates)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.aliases)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.functions)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.constants)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.enums)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine()); code.add(ApiPageCodeNewLine()); needsNewLine = false; }
    foreach(i, item; doc.variables)
    {
        if(i > 0) code.add(ApiPageCodeNewLine());
        code.add(getOverviewCommentForCode(item.model.comment));
        code.add(ApiPageCodeNewLine());
        appendCode(site, item, code, isNestedOverview);
        needsNewLine = true;
    }

    if(needsNewLine) { code.add(ApiPageCodeNewLine());  }
}

private void appendTypeRef(DocTypeRef typeRef, scope ref ApiPageDlangCode code, bool forceSingleLine = false)
{
    import std.sumtype : match;

    // TODO: Figure out situations where it's better to use the original type ref, e.g. for aliases?
    auto raw = typeRef.raw;

    const isFunction = raw.match!((DocFunctionType _) => true, (_) => false);

    if(!isFunction)
    {
        foreach(class_; typeRef.storageClasses)
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, (cast(string)class_) ~ " "));
    }

    void appendSymbolRef(DocSymbolReference type){
        const wasResolved = type.moduleFqnComponents.length > 0;
        string[] symbolStack;

        foreach(i, item; type.items)
        {
            item.match!(
                (DocSymbolDirectReference symbol){
                    symbolStack ~= symbol.symbolName;

                    auto text = ApiPageCodeText(ApiPageCodeText.Syntax.symbol, symbol.symbolName);
                    if(wasResolved)
                        code.add(text.asNavLink(type.moduleFqnComponents ~ symbolStack));
                    else
                        code.add(text.asCodeComponent);
                },
                (DocSymbolUnhandled symbol){
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "???"));
                },
                (DocSymbolInstanceReference symbol){
                    symbolStack ~= symbol.symbolName;

                    auto text = ApiPageCodeText(ApiPageCodeText.Syntax.symbol, symbol.symbolName);
                    if(wasResolved)
                        code.add(text.asNavLink(type.moduleFqnComponents ~ symbolStack));
                    else
                        code.add(text.asCodeComponent);

                    const useSingleLine = forceSingleLine || false; // TODO: Figure out conditions for when to split to multiple lines that actually looks good.
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "!("));
                    if(!useSingleLine)
                    {
                        code.add(ApiPageCodeNewLine());
                        code.add(ApiPageCodeIndent());
                    }

                    foreach(i, sumType; symbol.parameters)
                    {
                        if(i > 0)
                        {
                            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ", "));

                            if(!forceSingleLine)
                                code.add(ApiPageCodeNewLine());
                        }

                        sumType.match!(
                            (DocExpression param){
                                appendExpression(param, code, forceSingleLine);
                            },
                            (DocSymbolReference* param){
                                appendSymbolRef(*param);
                            },
                            (DocTypeRef* param){
                                appendTypeRef(*param, code, forceSingleLine);
                            },
                        );
                    }

                    if(!useSingleLine)
                    {
                        code.add(ApiPageCodeNewLine());
                        code.add(ApiPageCodeDedent());
                    }
                    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ")"));
                },
            );
        }
    }

    raw.match!(
        (DocSymbolReference type){
            appendSymbolRef(type);
        },
        (DocArrayType type){
            appendTypeRef(*type.underlyingTypeRef, code, forceSingleLine);
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "[]"));
        },
        (DocAssociativeArrayType type){
            appendTypeRef(*type.valueTypeRef, code, forceSingleLine);
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "["));
            appendTypeRef(*type.keyTypeRef, code, forceSingleLine: true);
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "]"));
        },
        (DocStaticArrayType type){
            appendTypeRef(*type.underlyingTypeRef, code, forceSingleLine);
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "["));
            appendExpression(type.arraySizeExpression, code, forceSingleLine: true);
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "]"));
        },
        (DocBasicType type){
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, type.name));
        },
        (DocPointerType type){
            appendTypeRef(*type.underlyingTypeRef, code, forceSingleLine);
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "*"));
        },
        (DocFunctionType type){
            if(type.returnType !is null)
                appendTypeRef(*type.returnType, code, forceSingleLine);
            else
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "auto"));

            if(type.isDelegate)
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, " delegate"));
            else
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, " function"));

            appendRuntimeParams(type.parameters, code, forceSingleLine);

            if(typeRef.storageClasses.length > 0)
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.none, " "));

            foreach(class_; typeRef.storageClasses)
                code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, (cast(string)class_) ~ " "));
        },
    );
}

private void appendExpression(DocExpression exp, scope ref ApiPageDlangCode code, bool forceSingleLine = false)
{
    import std.sumtype : match;

    exp.match!(
        (DocFallbackExpression expression){
            code.add(ApiPageCodeText(ApiPageCodeText.Syntax.expression, expression.renderedCode));
        }
    );
}

private void appendModuleStatement(SiteRoot site, DocModule mod, scope ref ApiPageDlangCode code)
{
    import std.string : join;

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "module "));
    code.add(ApiPageCodeText(text: mod.fqnComponents.join(".")).asNavLink(mod.fqnComponents ~ site.groupNavIndexId));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ";"));
    code.add(ApiPageCodeNewLine());
    code.add(ApiPageCodeNewLine());
}

private void appendLinkage(DocLinkage linkage, scope ref ApiPageDlangCode code)
{
    if(linkage == DocLinkage.d || linkage == DocLinkage.default_)
        return;

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, "extern"));
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, "("));
    final switch(linkage) with(DocLinkage)
    {
        case default_:
        case d:
            assert(false);
    
        case c:
            code.add(ApiPageCodeText(text: "C"));
            break;
        case cpp:
            code.add(ApiPageCodeText(text: "C++"));
            break;
        case windows:
            code.add(ApiPageCodeText(text: "Windows"));
            break;
        case objc:
            code.add(ApiPageCodeText(text: "Objective-C"));
            break;
        case system:
            code.add(ApiPageCodeText(text: "System"));
            break;
    }
    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, ") "));
}

private void appendVisibility(DocVisibility vis, scope ref ApiPageDlangCode code)
{
    if(vis == DocVisibility.public_ || vis == DocVisibility.undefined)
        return;

    code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, cast(string)vis ~ " "));
}

private void appendAggregateStorageClasses(DocStorageClass[] classes, scope ref ApiPageDlangCode code)
{
    foreach(class_; classes)
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.keyword, (cast(string)class_) ~ " "));
}

/++ Doc model helpers ++/

// If a DocTemplate is determined to be eponymous, then it'll get collapsed into this type so it's easier to handle optionally-templated types.
private struct MaybeTemplated(DocModelT)
{
    import std.typecons : Nullable;

    DocModelT model;
    Nullable!DocTemplate eponymousTemplate;

    this(DocModelT model)
    {
        this.model = model;
    }

    this(DocModelT model, DocTemplate eponymousTemplate)
    {
        this.model = model;
        this.eponymousTemplate = eponymousTemplate;
    }

    Nullable!DocComment comment() => (this.model.comment.isNull && !this.eponymousTemplate.isNull)
        ? this.eponymousTemplate.get.comment
        : this.model.comment;
}

private struct SymbolLeaf(DocModelT)
{
    DocModule module_;
    DocModelT model;
    string[] memberComponents; // `mod1` -> []; `mod1.Class` -> ["Class"]; `mod1.Class.Subclass` -> ["Class", "Subclass"];

    static typeof(this) fromModel(DocModule parentModule, DocModelT inputModel, string[] parentMemberComponents = [])
    {
        import std.sumtype : match;

        typeof(this) tree;
        tree.module_ = parentModule;
        tree.model = inputModel;

        static if(is(DocModelT : MaybeTemplated!T, T))
            auto model = inputModel.model;
        else
            auto model = inputModel;

        static if(__traits(hasMember, typeof(model), "name"))
            tree.memberComponents = parentMemberComponents ~ model.name;
        else
            assert(tree.memberComponents.length == 0);

        return tree;
    }
}

private struct SymbolTree(DocModelT)
{
    DocModule module_;
    DocModelT model;
    string[] memberComponents; // `mod1` -> []; `mod1.Class` -> ["Class"]; `mod1.Class.Subclass` -> ["Class", "Subclass"];

    SymbolTree!(MaybeTemplated!DocClass)[] classes;
    SymbolTree!(MaybeTemplated!DocStruct)[] structs;
    SymbolTree!(MaybeTemplated!DocUnion)[] unions;
    SymbolTree!DocTemplate[] templates; // Generally: Non-eponymous or eponymous but still has multiple members.

    SymbolLeaf!(MaybeTemplated!DocAlias)[] aliases;
    SymbolLeaf!(MaybeTemplated!DocFunction)[] functions;
    SymbolLeaf!(MaybeTemplated!DocManifestConstant)[] constants;
    SymbolLeaf!DocEnum[] enums;
    SymbolLeaf!DocVariable[] variables;

    size_t directChildCount() =>
        this.classes.length
        + this.structs.length
        + this.unions.length
        + this.templates.length
        + this.aliases.length
        + this.functions.length
        + this.constants.length
        + this.enums.length
        + this.variables.length;

    static typeof(this) fromModel(DocModule parentModule, DocModelT inputModel, string[] parentMemberComponents = [])
    {
        import std.algorithm : startsWith;
        import std.sumtype   : match;

        typeof(this) tree;
        tree.module_ = parentModule;
        tree.model = inputModel;

        static if(is(DocModelT : MaybeTemplated!T, T))
            auto model = inputModel.model;
        else
            auto model = inputModel;

        static if(__traits(hasMember, typeof(model), "name"))
            tree.memberComponents = parentMemberComponents ~ model.name;
        else
            assert(tree.memberComponents.length == 0);

        // Special case DocModelRoot
        static if(is(DocModelT == DocModelRoot))
        {
            auto nestedTypes = model.module_.nestedTypes;
            auto unaryTypes  = model.module_.members;
        }
        else
        {
            auto nestedTypes = model.nestedTypes;
            auto unaryTypes  = model.members;
        }

        static bool shouldIgnore(T)(T value)
        {
            static if(__traits(hasMember, T, "visibility"))
                return !(value.visibility == DocVisibility.public_ || value.visibility == DocVisibility.undefined);
            else
                return false;
        }

        foreach(aggregate; nestedTypes)
        {
            aggregate.match!(
                (DocStruct item) {
                    if(shouldIgnore(item)) return;
                    auto notTemplated = MaybeTemplated!DocStruct(item);
                    tree.structs ~= typeof(tree.structs[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocClass item) {
                    if(shouldIgnore(item)) return;
                    auto notTemplated = MaybeTemplated!DocClass(item);
                    tree.classes ~= typeof(tree.classes[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocUnion item) {
                    if(shouldIgnore(item)) return;
                    auto notTemplated = MaybeTemplated!DocUnion(item);
                    tree.unions ~= typeof(tree.unions[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocEnum item) {
                    if(shouldIgnore(item)) return;
                    tree.enums ~= typeof(tree.enums[0]).fromModel(parentModule, item, tree.memberComponents);
                },
                (DocTemplate item) {
                    if(shouldIgnore(item)) return;
                    // If the template has only one member; that member has the same name as the template, and that member
                    // isn't also a DocTemplate, then treat it as eponymous.
                    const hasOneMember = (item.members.length + item.nestedTypes.length == 1);
                    const hasSameName =
                        item.members.length > 0
                        ? item.members[0].match!((member) => member.name == item.name)
                        : item.nestedTypes.length > 0 
                            ? item.nestedTypes[0].match!((type) => type.name == item.name)
                            : false;
                    
                    // I _could_ DRY this but it's more of a hassle than it's worth IMO.
                    if(hasOneMember && hasSameName)
                    {
                        const wasTemplatable =
                            item.members.length > 0
                            ? item.members[0].match!(
                                (DocManifestConstant member) {
                                    if(shouldIgnore(item)) return false;
                                    auto templated = MaybeTemplated!DocManifestConstant(member, item);
                                    tree.constants ~= typeof(tree.constants[0]).fromModel(parentModule, templated, tree.memberComponents);
                                    return true;
                                },
                                (DocFunction member) {
                                    if(shouldIgnore(item)) return false;
                                    if(item.name.startsWith("__")) return false;
                                    auto templated = MaybeTemplated!DocFunction(member, item);
                                    tree.functions ~= typeof(tree.functions[0]).fromModel(parentModule, templated, tree.memberComponents);
                                    return true;
                                },
                                (DocAlias member) {
                                    if(shouldIgnore(item)) return false;
                                    auto templated = MaybeTemplated!DocAlias(member, item);
                                    tree.aliases ~= typeof(tree.aliases[0]).fromModel(parentModule, templated, tree.memberComponents);
                                    return true;
                                },
                                (_) => false,
                            )
                            : item.nestedTypes[0].match!(
                                (DocStruct type) {
                                    if(shouldIgnore(item)) return false;
                                    auto templated = MaybeTemplated!DocStruct(type, item);
                                    tree.structs ~= typeof(tree.structs[0]).fromModel(parentModule, templated, tree.memberComponents);
                                    return true;
                                },
                                (DocClass type) {
                                    if(shouldIgnore(item)) return false;
                                    auto templated = MaybeTemplated!DocClass(type, item);
                                    tree.classes ~= typeof(tree.classes[0]).fromModel(parentModule, templated, tree.memberComponents);
                                    return true;
                                },
                                (DocUnion type) {
                                    if(shouldIgnore(item)) return false;
                                    auto templated = MaybeTemplated!DocUnion(type, item);
                                    tree.unions ~= typeof(tree.unions[0]).fromModel(parentModule, templated, tree.memberComponents);
                                    return true;
                                },
                                (_) => false,
                            );

                        if(wasTemplatable)
                            return;
                    }

                    // Otherwise just treat it as a straight up template.
                    tree.templates ~= typeof(tree.templates[0]).fromModel(parentModule, item, tree.memberComponents);
                },
            );
        }

        foreach(unary; unaryTypes)
        {
            unary.match!(
                (DocManifestConstant item) {
                    if(shouldIgnore(item)) return;
                    auto notTemplated = MaybeTemplated!DocManifestConstant(item);
                    tree.constants ~= typeof(tree.constants[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocFunction item) {
                    if(shouldIgnore(item)) return;
                    if(item.name.startsWith("__")) return;
                    auto notTemplated = MaybeTemplated!DocFunction(item);
                    tree.functions ~= typeof(tree.functions[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocAlias item) {
                    if(shouldIgnore(item)) return;
                    auto notTemplated = MaybeTemplated!DocAlias(item);
                    tree.aliases ~= typeof(tree.aliases[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocVariable item) {
                    if(shouldIgnore(item)) return;
                    tree.variables ~= typeof(tree.variables[0]).fromModel(parentModule, item, tree.memberComponents);
                },
                (DocRuntimeParameter item) { /* This shouldn't ever really actually happen... why is the doc model even like this lol? */ },
            );
        }

        return tree;
    }
}