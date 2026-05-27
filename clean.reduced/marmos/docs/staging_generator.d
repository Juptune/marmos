module marmos.docs.staging_generator;

import std;
import marmos.converter.model; // Intentionally everything

import marmos.docs.discover : SiteRoot, RootGroup;
import marmos.docs.staging_models;

void generateAndEmitGroupStagingFiles(SiteRoot site, RootGroup group)
{
    import marmos.docs.discover ;

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
}

void buildAndEmitChildPages(DocModelT)(
    RootGroup group,
    SiteRoot site,
DocModelT tree,
GroupNavRoot nav,
    bool hideNavItem = false,
)
{
    // NOTE: _Technically_ aggregate types can also have multiple definitions due to conditional compliation... but TODO: for now the last one wins.
    foreach(item; tree.classes) buildAndEmitAggregatePage!"Classes"(group, site, item, nav, hideNavItem);
}

void buildAndEmitAggregatePage(string TypeName, DocModelT)(
    RootGroup ,
    SiteRoot site,
DocModelT tree,
GroupNavRoot ,
    bool ,
)
{
    ApiPageRoot page;

    page.add(buildDlangCodeBlock(site, tree));

}

ApiPageDlangCode buildDlangCodeBlock(TreeOrLeafT)(SiteRoot , TreeOrLeafT treeOrLeaf)
{
    ApiPageDlangCode code;
    appendCode(treeOrLeaf);

    return code;
}

void appendCode(SymbolTree!(MaybeTemplated!DocClass) doc)
{
    DocClass model = doc.model.model;

        foreach(inter; model.interfaces)
            appendTypeRef(inter);
}

void appendTypeRef(DocTypeRef typeRef)
{
    // TODO: Figure out situations where it's better to use the original type ref, e.g. for aliases?
    auto raw = typeRef.raw;

    void appendSymbolRef(DocSymbolReference type){
        foreach(item; type.items)
            // NOTE: wtf, why does deleting this stop the crash?
            item.match!(
                (DocSymbolInstanceReference ){
                }            );
    }

    raw.match!(
        (type){
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
        (DocFunctionType ){
        }    );
}

struct MaybeTemplated(DocModelT)
{
    DocModelT model;
}

struct SymbolTree(DocModelT)
{
    DocModelT model;
    SymbolTree!(MaybeTemplated!DocClass)[] classes;
    static typeof(this) fromModel(DocModule parentModule, DocModelT inputModel)
    {
        typeof(this) tree;
        tree.model = inputModel;

        static if(is(DocModelT : MaybeTemplated!T, T))
            auto model = inputModel.model;
        else
            auto model = inputModel;

        // Special case DocModelRoot
        static if(is(DocModelT == DocModelRoot))
            auto nestedTypes = model.module_.nestedTypes;
        else
            auto nestedTypes = model.nestedTypes;
        foreach(aggregate; nestedTypes)
            aggregate.match!(
                (item) {
                    auto notTemplated = MaybeTemplated!DocClass(item);
                    tree.classes ~= tree.classes[0].fromModel(parentModule, notTemplated);
                },
                (DocUnion item) {
                },
                (DocEnum item) {
                },
                (DocTemplate ) {
                }            );
        return tree;
    }
}