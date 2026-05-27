module marmos.docs.config_models;

import std;

import marmos.converter.json ;

struct MardocsConfig
{
}

/++ Root groups ++/

alias RootGroupKind = SumType!(
    MarmosDocModelGroup,

    // NOTE: The crash seems to dissapear if these lines are commented out - comment them (and the ones in discover.d marked with a NOTE) to stop the crash.
    SingleFileGroup,
    GroupOfGroups,
);

struct RootGroup
{
    RootGroupKind kind;
}

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

