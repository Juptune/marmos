/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.docs.discover;

import std.logger  : infof;
import std.sumtype : SumType, match;

static import conf = marmos.docs.config_models; // Intentionally everything

SiteRoot discoverSite(string rootDir, conf.MardocsConfig config)
{
    SiteRoot root;
    root.config = config;
    root.rootDir = rootDir;

    const dirs = expectOnlyDirsListed(root.siteDir(), debugName: "site root directory");
    const sortedDirs = sortDirsByOrderPrefix(dirs);

    foreach(dir; sortedDirs)
    {
        auto group = loadRootGroup(dir);
        debug if(group is null)
            continue;
        assert(group !is null);
        root.rootGroups ~= group;
    }

    return root;
}

void discoverStagingSite(scope ref SiteRoot root)
{
    auto dirs = expectOnlyDirsListed(root.stagingGroupsRootDir(), debugName: "staging groups directory");

    foreach(dir; dirs)
    {
        auto group = loadStagingRootGroup(dir);
        root.stagingRootGroups ~= group;
    }
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
    StagingRootGroup[] stagingRootGroups;

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

    string groupName() => titleFromDirName(this._groupDir);
    string groupDir() => this._groupDir;
    string groupUrlName()
    {
        import std.string : replace;
        import std.uni    : toLower;
        import std.uri    : encode;

        return this.groupName.replace(" ", "-").toLower().encode;
    }
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
            // Skip stuff like _config.json
            if(entry.baseName[0] == '_')
                continue;

            infof("[%s] discovered: %s", super.groupName, entry.name.baseName);

            enforce(!entry.isDir, format("MarmosDocModelGroup does not support subdirectories: %s", entry));
            enforce(entry.extension == ".json", format("MarmosDocModelGroup only supports .json files: %s", entry));
            this._modelFilePaths ~= entry.name;
        }
    }

    string[] modelFilePaths() => this._modelFilePaths;
}

abstract class StagingRootGroup : RootGroup
{
    private alias ConfigSumType = SumType!(
        StagingApiRefGroup.ConfigModel
    );

    this(string groupDir)
    {
        super(groupDir);
    }
}

final class StagingApiRefGroup : StagingRootGroup
{
    import marmos.docs.staging_models : GroupNavRoot;

    struct ConfigModel {}

    static struct Page
    {
        string sourceModelPath;
        string htmlOutputSubpath;
    }
    
    static struct Version
    {
        Page[] pages;
        GroupNavRoot navRoot;
    }

    private
    {
        Version[string] _versionsByName;
    }

    this(string groupDir)
    {
        import std.exception : enforce;
        import std.file      : SpanMode, DirEntry, dirEntries, isFile;
        import std.format    : format;
        import std.path      : extension, setExtension, baseName, relativePath, absolutePath, buildNormalizedPath;

        super(groupDir);

        foreach(DirEntry entry; dirEntries(super.groupDir, SpanMode.shallow))
        {
            // Skip other stuff like _config.json
            if(entry.name.isFile)
                continue;

            infof("[%s] discovered version: %s", super.groupDir.baseName, entry.name.baseName);

            Version version_;

            foreach(DirEntry model; dirEntries(entry.name, SpanMode.breadth))
            {
                const relative = relativePath(absolutePath(model.name), absolutePath(entry.name));
                if(relative == "navigation.json")
                {
                    version_.navRoot = loadJsonModel!GroupNavRoot(model.name);
                    continue;
                }

                if(model.isDir)
                    continue;

                version_.pages ~= Page(model.name, buildNormalizedPath(groupDir.baseName, entry.baseName, relative).setExtension(".html"));
            }

            this._versionsByName[entry.name] = version_;
        }
    }

    Version[string] versionsByName() => this._versionsByName;
}

/++ Loading ++/

private RootGroup loadRootGroup(string dir)
{
    import std.path : buildNormalizedPath;

    auto rootConfig = loadJsonModel!(conf.RootGroup)(buildNormalizedPath(dir, "_config.json"));
    return rootConfig.kind.match!(
        (conf.MarmosDocModelGroup _) => new MarmosDocModelRootGroup(dir),
        (conf.SingleFileGroup _) { infof("TODO"); return null; },
        (conf.GroupOfGroups _) { infof("TODO"); return null; },
    );
}

private StagingRootGroup loadStagingRootGroup(string dir)
{
    import std.path : buildNormalizedPath;

    auto rootConfig = loadJsonModel!(StagingRootGroup.ConfigSumType)(buildNormalizedPath(dir, "_config.json"));
    return rootConfig.match!(
        (StagingApiRefGroup.ConfigModel _) => new StagingApiRefGroup(dir),
    );
}

package ModelT loadJsonModel(ModelT)(string file)
{
    import std.file : readText;
    import std.json : parseJSON;
    
    import marmos.converter.json : jsonToDoc;

    infof("loading %s from: %s", ModelT.stringof, file);

    const text = readText(file);
    auto json = parseJSON(text);
    return jsonToDoc!ModelT(json);
}

/++ Helpers ++/

private string[] expectOnlyDirsListed(string path, string debugName)
{
    import std.exception : enforce;
    import std.file      : DirEntry, SpanMode, dirEntries;
    import std.format    : format;

    infof("[%s] listing directories in: %s", debugName, path);

    string[] result;

    foreach(DirEntry entry; dirEntries(path, SpanMode.shallow))
    {
        enforce(entry.isDir, format("%s only supports subdirectories: %s", debugName, path));
        result ~= entry.name;
    }

    infof("[%s] found: %s", debugName, result);
    return result;
}

private string[] sortDirsByOrderPrefix(const string[] dirs)
{
    import std.conv         : to;
    import std.exception    : enforce;
    import std.format       : format;
    import std.path         : dirName, baseName;

    string[] result;
    result.length = dirs.length;

    // cba to deal with ranges autodecoding, so I'm using a foreach
    foreach(dir; dirs)
    {
        uint order = uint.max;

        // Split by hyphen, and convert the left-hand element to a number
        foreach(i, ch; dir.baseName)
        {
            if(ch == '-')
            {
                order = dir.baseName[0..i].to!uint;
                break;
            }
        }
        enforce(order != uint.max, format("expected directory to have an order prefix, e.g. '0-%s': %s", dir.baseName, dir)); // @suppress(dscanner.style.long_line)
        enforce(order < result.length, format("order prefix must be between 0 and %s inclusive. Got %s: %s", dirs.length, order, dir)); // @suppress(dscanner.style.long_line)

        result[order] = dir;
    }

    infof("sorted dirs by order prefix: %s", result);
    return result;
}

private string titleFromDirName(string dir)
{
    import std.path : baseName;

    foreach(i, ch; dir.baseName)
    {
        if(ch == '-')
            return dir.baseName[i+1..$];
    }

    return dir.baseName;
}