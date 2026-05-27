module marmos.docs.config_models;

import std.sumtype : SumType;

import marmos.converter.json : JsonType;

@JsonType("MardocsConfig@1")
struct MardocsConfig
{
    string siteTitle;
}

/++ Root groups ++/

alias RootGroupKind = SumType!(
    MarmosDocModelGroup,

    // NOTE: The crash seems to dissapear if these lines are commented out - comment them (and the ones in discover.d marked with a NOTE) to stop the crash.
    SingleFileGroup,
    GroupOfGroups,
);

alias SubGroupKind = SumType!(
    MarkdownDocGroup
);

@JsonType("RootGroup@1")
struct RootGroup
{
    RootGroupKind kind;
}

@JsonType("MarmosDocModelGroup@1")
struct MarmosDocModelGroup
{

}

@JsonType("SingleFileGroup@1")
struct SingleFileGroup
{

}

@JsonType("GroupOfGroups@1")
struct GroupOfGroups
{

}

/++ Sub groups/articles ++/

@JsonType("SubGroup@1")
struct SubGroup
{
    SubGroupKind kind;
}

@JsonType("MarkdownDocGroup@1")
struct MarkdownDocGroup
{

}