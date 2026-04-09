module marmos.context;

final class MarmosContext
{
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
    }

    void enableFeature(Features feature)
    {
        this._features |= feature;
    }

    void addImportPath(string path)
    {
        this._importPaths ~= path;
    }

    void addImportPath(string[] paths)
    {
        this._importPaths ~= paths;
    }

    void addStringImportPath(string path)
    {
        this._stringImportPaths ~= path;
    }

    void addStringImportPath(string[] paths)
    {
        this._stringImportPaths ~= paths;
    }

    void useDefaultConf(bool value)
    {
        this._useDefaultConf = value;
    }

    /++ Getters ++/

    bool isFeatureEnabled(Features feature) => (this._features & feature) == feature;
    string[] getImportPaths() => this._importPaths;
    string[] getStringImportPaths() => this._stringImportPaths;
    bool useDefaultConf() => this._useDefaultConf;
}