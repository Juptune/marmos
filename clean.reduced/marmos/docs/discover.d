module marmos.docs.discover;

import std;
import conf = marmos.docs.config_models; // Intentionally everything

SiteRoot discoverSite(string rootDir, conf.MardocsConfig )
{
    SiteRoot root;
    root.rootDir = rootDir;

    string[] result;
    foreach(entry; dirEntries(root.siteDir, SpanMode.shallow))
        result ~= entry;

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
    string rootDir;
    RootGroup[] rootGroups;

    /++ Main directories ++/
    string siteDir() => buildNormalizedPath(rootDir, "site");
}

class RootGroup
{
    this(string )
    {
    }

}

class MarmosDocModelRootGroup : RootGroup
{
        string[] _modelFilePaths;
    this(string groupDir)
    {
        super(groupDir);

        foreach(entry; dirEntries(groupDir, SpanMode.shallow))
_modelFilePaths ~= entry;
    }

    string[] modelFilePaths() => _modelFilePaths;
}


RootGroup loadRootGroup(string dir)
{
    auto rootConfig = loadJsonModel!(conf.RootGroup)(buildNormalizedPath(dir, "_config.json"));
    return rootConfig.kind.match!(
        (conf.MarmosDocModelGroup ) => new MarmosDocModelRootGroup(dir),

        // NOTE: The crash seems to dissapear if these lines are commented out - comment them (and the ones in config_models.d marked with a NOTE) to stop the crash.
        (conf.SingleFileGroup ) { return null; },
        (conf) { return null; }    );
}


ModelT loadJsonModel(ModelT)(string file)
{
    
    import marmos.converter.json ;

    const text = readText(file);
    auto json = parseJSON(text);
    return jsonToDoc!ModelT(json);
}