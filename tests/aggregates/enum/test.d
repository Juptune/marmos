module test;

enum Normal
{
    abc,
    oneTwoThree
}

enum ExplicitBase : short
{
    abc
}

enum SymbolOnly;

enum ManifestConstant = 1;

enum short ExplicitManifestConstant = 2;