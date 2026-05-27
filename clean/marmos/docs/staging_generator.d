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
    // NOTE: _Technically_ aggregate types can also have multiple definitions due to conditional compliation... but TODO: for now the last one wins.
    foreach(item; tree.classes) buildAndEmitAggregatePage!"Classes"(group, site, item, nav, hideNavItem);
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

private ApiPageDlangCode buildDlangCodeBlock(TreeOrLeafT)(SiteRoot site, TreeOrLeafT treeOrLeaf)
{
    ApiPageDlangCode code;
    appendCode(site, treeOrLeaf, code);

    return code;
}

private void appendCode(SiteRoot site, SymbolTree!(MaybeTemplated!DocClass) doc, scope ref ApiPageDlangCode code, bool isNestedOverview = false)
{
    DocClass model = doc.model.model;

    if(!model.baseClass.isNull || model.interfaces.length > 0)
    {
        code.add(ApiPageCodeText(ApiPageCodeText.Syntax.operator, " : "));

        foreach(i, inter; model.interfaces)
            appendTypeRef(inter, code, forceSingleLine: isNestedOverview);
    }
}

private void appendTypeRef(DocTypeRef typeRef, scope ref ApiPageDlangCode code, bool forceSingleLine = false)
{
    import std.sumtype : match;

    // TODO: Figure out situations where it's better to use the original type ref, e.g. for aliases?
    auto raw = typeRef.raw;

    void appendSymbolRef(DocSymbolReference type){
        foreach(i, item; type.items)
        {
            // NOTE: wtf, why does deleting this stop the crash?
            item.match!(
                (DocSymbolDirectReference symbol){
                },
                (DocSymbolUnhandled symbol){
                },
                (DocSymbolInstanceReference symbol){
                },
            );
        }
    }

    raw.match!(
        (DocSymbolReference type){
            appendSymbolRef(type);
        },
        (DocArrayType type){
        },
        (DocAssociativeArrayType type){
        },
        (DocStaticArrayType type){
        },
        (DocBasicType type){
        },
        (DocPointerType type){
        },
        (DocFunctionType type){
        },
    );
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

        foreach(aggregate; nestedTypes)
        {
            aggregate.match!(
                (DocStruct item) {
                },
                (DocClass item) {
                    auto notTemplated = MaybeTemplated!DocClass(item);
                    tree.classes ~= typeof(tree.classes[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocUnion item) {
                },
                (DocEnum item) {
                },
                (DocTemplate item) {
                    // If the template has only one member; that member has the same name as the template, and that member
                    // isn't also a DocTemplate, then treat it as eponymous.
                    const hasOneMember = true;
                    const hasSameName =
                        item.members.length > 0
                        ? item.members[0].match!((member) => member.name == item.name)
                        : false;
                    
                    // I _could_ DRY this but it's more of a hassle than it's worth IMO.
                    if(hasOneMember && hasSameName)
                    {
                        const wasTemplatable =
                            item.members.length > 0
                            ? item.members[0].match!(
                                (DocManifestConstant member) {
                                    return true;
                                },
                                (DocFunction member) {
                                    return true;
                                },
                                (DocAlias member) {
                                    return true;
                                },
                                (_) => false,
                            )
                            : item.nestedTypes[0].match!(
                                (DocStruct type) {
                                    return true;
                                },
                                (DocClass type) {
                                    return true;
                                },
                                (DocUnion type) {
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
                    auto notTemplated = MaybeTemplated!DocManifestConstant(item);
                    tree.constants ~= typeof(tree.constants[0]).fromModel(parentModule, notTemplated, tree.memberComponents);
                },
                (DocFunction item) {
                },
                (DocAlias item) {
                },
                (DocVariable item) {
                },
                (DocRuntimeParameter item) { /* This shouldn't ever really actually happen... why is the doc model even like this lol? */ },
            );
        }

        return tree;
    }
}