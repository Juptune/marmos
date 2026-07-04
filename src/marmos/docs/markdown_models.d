/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.docs.markdown_models;

import std.sumtype : SumType;

import marmos.converter.json : JsonType, JsonField;

alias MarkdownContainer = SumType!(
    MarkdownParagraph,
    MarkdownHeader,
    MarkdownListItem,
    MarkdownCodeBlock,
);

alias MarkdownInline = SumType!(
    MarkdownPlainText,
    MarkdownBoldText,
    MarkdownItalicText,
    MarkdownCodeText,
    MarkdownLink,
);

@JsonType("r")
struct MarkdownRoot
{
    @JsonField("m") MarkdownMetadata metadata;
    @JsonField("c") MarkdownContainer[] containers;
}

@JsonType("m")
struct MarkdownMetadata
{
    @JsonField("p") string[string] keyValuePairs;
}

/++ Containrs ++/

@JsonType("p")
struct MarkdownParagraph
{
    @JsonField("i") MarkdownInline[] inlines;
}

@JsonType("h")
struct MarkdownHeader
{
    @JsonField("l") uint level;
    @JsonField("i") MarkdownParagraph inner;
}

@JsonType("li")
struct MarkdownListItem
{
    @JsonField("o") bool isOrdered;
    @JsonField("l") uint level;
    @JsonField("i") MarkdownParagraph inner;
}

@JsonType("cb")
struct MarkdownCodeBlock
{
    @JsonField("l") string language;
    @JsonField("t") string rawText;
}

/++ Inlines ++/

@JsonType("t")
struct MarkdownPlainText
{
    @JsonField("t") string text;
}

@JsonType("b")
struct MarkdownBoldText
{
    @JsonField("i") MarkdownInline* inner;
}

@JsonType("i")
struct MarkdownItalicText
{
    @JsonField("i") MarkdownInline* inner;
}

@JsonType("ct")
struct MarkdownCodeText
{
    @JsonField("i") MarkdownInline* inner;
}

@JsonType("l")
struct MarkdownLink
{
    @JsonField("t") string text;
    @JsonField("h") string href;
}