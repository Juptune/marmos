/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
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