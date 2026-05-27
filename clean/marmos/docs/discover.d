module marmos.docs.discover;

import std.logger  : infof;
import std.sumtype : SumType, match;

static import conf = marmos.docs.config_models; // Intentionally everything

SiteRoot discoverSite(string rootDir, conf.MardocsConfig config)
{
    import std.file;

    SiteRoot root;
    root.config = config;
    root.rootDir = rootDir;

    string[] result;
    foreach(DirEntry entry; dirEntries(root.siteDir(), SpanMode.shallow))
        result ~= entry.name;

    foreach(dir; result)
    {
        auto group = loadRootGroup(dir);
        root.rootGroups ~= group;
    }

    return root;
}

/++ Discovery Models ++/

struct SiteRoot
{
    import std.path : buildNormalizedPath;

    import marmos.converter.model    : DocModule;
    import marmos.docs.config_models : MardocsConfig;

    string rootDir;
    MardocsConfig config;
    RootGroup[] rootGroups;

    /++ Main directories ++/
    string siteDir() => buildNormalizedPath(this.rootDir, "site");
    string stagingDir() => /+WARNING: The generate command will delete this directory, please be careful if changing its value+/ buildNormalizedPath(this.rootDir, "_staging");
    string buildDir() => /+WARNING: The generate command will delete this directory, please be careful if changing its value+/ buildNormalizedPath(this.rootDir, "_build");
    string stagingGroupsRootDir() => buildNormalizedPath(this.stagingDir, "groups");

    /++ Staging files, dirs, and other ids ++/
    string navbarFile() => buildNormalizedPath(this.stagingDir, "navbar.json");
    string groupStagingDir(string groupName, string apiVersion) => buildNormalizedPath(this.stagingDir, "groups", groupName, apiVersion);
    string groupNavFile(string groupName, string apiVersion) => buildNormalizedPath(this.groupStagingDir(groupName, apiVersion), "navigation.json");
    string groupRootConfigFile(string groupName) => buildNormalizedPath(this.stagingGroupsRootDir, groupName, "_config.json");
    
    string groupModuleIndexFile(string groupName, DocModule mod, string apiVersion) 
        => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ "index.json");
    
    string groupModuleClassesIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["classes"] ~ memberComponents ~ "index.json");
    string groupModuleStructsIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["structs"] ~ memberComponents ~ "index.json");
    string groupModuleUnionsIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["unions"] ~ memberComponents ~ "index.json");
    string groupModuleTemplatesIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["templates"] ~ memberComponents ~ "index.json");
    string groupModuleAliasesIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["aliases"] ~ memberComponents ~ "index.json");
    string groupModuleFunctionsIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["functions"] ~ memberComponents ~ "index.json");
    string groupModuleConstantsIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["constants"] ~ memberComponents ~ "index.json");
    string groupModuleEnumsIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["enums"] ~ memberComponents ~ "index.json");
    string groupModuleVariablesIndexFile(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupStagingDir(groupName, apiVersion)] ~ mod.fqnComponents ~ ["variables"] ~ memberComponents ~ "index.json");

    string groupNavIndexId() => "__index";

    string[] groupNavClassesIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["classes"] ~ ids);
    string[] groupNavStructsIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["structs"] ~ ids);
    string[] groupNavUnionsIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["unions"] ~ ids);
    string[] groupNavTemplatesIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["templates"] ~ ids);
    string[] groupNavAliasesIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["aliases"] ~ ids);
    string[] groupNavFunctionsIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["functions"] ~ ids);
    string[] groupNavConstantsIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["constants"] ~ ids);
    string[] groupNavEnumsIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["enums"] ~ ids);
    string[] groupNavVariablesIdPath(DocModule mod, string[] ids) => (mod.fqnComponents ~ ["variables"] ~ ids);

    /++ HTML files, dirs, and href helpers ++/
    
    string groupHref(string groupName, string apiVersion) => "/" ~ buildNormalizedPath(groupName, apiVersion);

    string groupModuleIndexHref(string groupName, DocModule mod, string apiVersion) 
        => buildNormalizedPath([this.groupHref(groupName, apiVersion)] ~ mod.fqnComponents);

    string groupModuleClassesIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "classes"] ~ memberComponents);
    string groupModuleStructsIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "structs"] ~ memberComponents);
    string groupModuleUnionsIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "unions"] ~ memberComponents);
    string groupModuleTemplatesIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "templates"] ~ memberComponents);
    string groupModuleAliasesIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "aliases"] ~ memberComponents);
    string groupModuleFunctionsIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "functions"] ~ memberComponents);
    string groupModuleConstantsIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "constants"] ~ memberComponents);
    string groupModuleEnumsIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "enums"] ~ memberComponents);
    string groupModuleVariablesIndexHref(string groupName, DocModule mod, string[] memberComponents, string apiVersion) => buildNormalizedPath([this.groupModuleIndexHref(groupName, mod, apiVersion), "variables"] ~ memberComponents);

    string staticFileDirPath() => "static";
    string staticScriptPath(string scriptName) => buildNormalizedPath(this.staticFileDirPath, "scripts", scriptName);
    string apiRefGroupToggleJsPath() => this.staticScriptPath("api-reference-group-toggle.js");
}

abstract class RootGroup
{
    private
    {
        string _groupDir; // Normalised from cwd
    }

    this(string groupDir)
    {
        this._groupDir = groupDir;
    }

    string groupName() => ""; // omitted for reduced sample
    string groupDir() => this._groupDir;
    string groupUrlName() => ""; // omitted for reduced sample
}

final class MarmosDocModelRootGroup : RootGroup
{
    private
    {
        string[] _modelFilePaths;
    }

    this(string groupDir)
    {
        import std.exception : enforce;
        import std.file      : SpanMode, DirEntry, dirEntries;
        import std.format    : format;
        import std.path      : extension, baseName;

        super(groupDir);

        foreach(DirEntry entry; dirEntries(super.groupDir, SpanMode.shallow))
        {
            if(entry.baseName[0] == '_')
                continue;
            this._modelFilePaths ~= entry.name;
        }
    }

    string[] modelFilePaths() => this._modelFilePaths;
}


/++ Loading ++/

private RootGroup loadRootGroup(string dir)
{
    import std.path : buildNormalizedPath;

    auto rootConfig = loadJsonModel!(conf.RootGroup)(buildNormalizedPath(dir, "_config.json"));
    return rootConfig.kind.match!(
        (conf.MarmosDocModelGroup _) => new MarmosDocModelRootGroup(dir),

        // NOTE: The crash seems to dissapear if these lines are commented out - comment them (and the ones in config_models.d marked with a NOTE) to stop the crash.
        (conf.SingleFileGroup _) { infof("TODO"); return null; },
        (conf.GroupOfGroups _) { infof("TODO"); return null; },
    );
}


package ModelT loadJsonModel(ModelT)(string file)
{
    import std.file : readText;
    import std.json : parseJSON;
    
    import marmos.converter.json : jsonToDoc;

    const text = readText(file);
    auto json = parseJSON(text);
    return jsonToDoc!ModelT(json);
}