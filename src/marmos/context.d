module marmos.context;

final class MarmosContext
{
    import std.logger : infof;

    import dmd.dmodule : Module;

    // NOTE: This is a bit mask
    enum Features
    {
        none,
        semanticPass = 1 << 0
    }

    private
    {
        Features _features;
        string[] _importPaths;
        string[] _stringImportPaths;
        bool     _useDefaultConf;

        Module[string]  _parsedModulesByFqn;
        bool            _dmdHasInit;
    }

    /++ Other logic ++/

    void setupDmd()
    {
        import dmd.frontend : deinitializeDMD, initDMD, parseModule, findImportPaths, addImport, addStringImport;
        infof("Setting up DMD");

        if(this._dmdHasInit)
        {
            deinitializeDMD();
            this._dmdHasInit = false;
        }

        initDMD();

        foreach(imp; this._importPaths)
        {
            infof("adding explicit import path %s", imp);
            addImport(imp);
        }
        foreach(imp; this._stringImportPaths)
        {
            infof("adding explicit string import path %s", imp);
            addStringImport(imp);
        }

        if(this.useDefaultConf)
        {
            infof("Using default config");
            foreach(path; findImportPaths())
            {
                infof("adding default import path %s", path);
                addImport(path);
            }
        }
        
        this._dmdHasInit = true;
    }

    void parseModule(string file)
    in(this._dmdHasInit)
    {
        import std.exception : enforce;
        import dmd.frontend : parseModule;

        auto mod = parseModule(file).module_;
        enforce(mod.md !is null, "module at '"~file~"' does not have a `module` statement - this is currently required by marmos"); // @suppress(dscanner.style.long_line)
        enforce(mod.md.toString() !in this._parsedModulesByFqn, "multiple files for module '"~mod.md.toString()~"' were found"); // @suppress(dscanner.style.long_line)

        this._parsedModulesByFqn[mod.md.toString()] = mod;
    }

    void onDoneParsing()
    in(this._dmdHasInit)
    {
        import dmd.dsymbolsem : importAll, dsymbolSemantic, runDeferredSemantic;

        if(this.isFeatureEnabled(Features.semanticPass))
        {
            foreach(_, mod; this._parsedModulesByFqn)
            {
                // We only really care about imports and trying to resolve symbols, rather than full analysis.
                mod.importedFrom = mod;
                mod.importAll(null);

                mod.dsymbolSemantic(null);
                runDeferredSemantic();
            }
        }
    }

    /++ Setters ++/

    void enableFeature(Features feature)
    in(!this._dmdHasInit)
    {
        this._features |= feature;
    }

    void addImportPath(string path)
    in(!this._dmdHasInit)
    {
        this._importPaths ~= path;
    }

    void addImportPath(string[] paths)
    in(!this._dmdHasInit)
    {
        this._importPaths ~= paths;
    }

    void addStringImportPath(string path)
    in(!this._dmdHasInit)
    {
        this._stringImportPaths ~= path;
    }

    void addStringImportPath(string[] paths)
    in(!this._dmdHasInit)
    {
        this._stringImportPaths ~= paths;
    }

    void useDefaultConf(bool value)
    in(!this._dmdHasInit)
    {
        this._useDefaultConf = value;
    }

    /++ Getters ++/

    bool isFeatureEnabled(Features feature) => (this._features & feature) == feature;
    string[] getImportPaths() => this._importPaths;
    string[] getStringImportPaths() => this._stringImportPaths;
    bool useDefaultConf() => this._useDefaultConf;
}