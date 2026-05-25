/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.docs.staging_models;

import std.exception : enforce;
import std.sumtype   : SumType;

// These are internal models, so models that appear a lot or for any reason take up a lot of file space will use these UDAs to
// significantly reduce file sizes (easily over 50% for most code bases).
import marmos.converter.json : JsonType, JsonField;

/++ Root models (each model is probably in its own file in the staging folder) ++/

struct NavbarRoot
{
    /// Key is the user-facing name of the navbar item, value is a href to give it.
    string[string] entries;
}

struct GroupNavRoot
{
    @JsonType("N")
    static struct Node
    {
        enum Category : string
        {
            none = "n",
            module_ = "m",
        }

        @JsonField("i") string urlSafeId;
        @JsonField("n") string userFacingName;
        @JsonField("g") bool isGroup;
        @JsonField("v") bool isHidden; // A lot of links will source their href from nav tree entries, so even though there's a lot of symbols we don't want to show in the tree, we still need to generate their entries for the sake of links.
        @JsonField("t") Category category; // Helps determine whether the nav item is automatically collapsed or not by default.

        /++ Group values ++/

        @JsonField("c") Node[] children;

        /++ Leaf values ++/

        @JsonField("h") string href;
    }

    Node rootNode; // Used for the actual navigation list, notably things like nested enums would have a path of `mod1.Enums.Class1.MyEnum`
    Node nonVisibleRootNode; // More of a symbol table list, so things like nested enums would have a path of `mod1.Class1.MyEnum`

    Node* getOrMakeByIdPath(string[] urlSafeIdPath, bool isGroup, bool isHidden = false, Node.Category category = Node.Category.none)
        => this.getOrMakeByIdPathImpl(this.rootNode, urlSafeIdPath, isGroup, isHidden, category);

    Node* getOrMakeByIdPathHidden(string[] urlSafeIdPath)
        => this.getOrMakeByIdPathImpl(this.nonVisibleRootNode, urlSafeIdPath, isGroup: false, isHidden: true);

    private Node* getOrMakeByIdPathImpl(ref Node rootNode, string[] urlSafeIdPath, bool isGroup, bool isHidden = false, Node.Category category = Node.Category.none)
    in(urlSafeIdPath.length > 0, "id path must have at least 1 item")
    {
        // Allow empty entries at the end, to help access the parent node of ID path builders
        while(urlSafeIdPath[$-1].length == 0)
            urlSafeIdPath = urlSafeIdPath[0..$-1];
        assert(urlSafeIdPath.length > 0, "id path must have at least 1 NON-EMPTY item");

        Node* lookup(ref Node parent, string[] path)
        {
            if(path.length == 0)
                return &parent;

            foreach(ref child; parent.children)
            {
                if(child.urlSafeId == path[0])
                    return lookup(child, path[1..$]);
            }

            // Create missing node(s)
            parent.children ~= Node(path[0], isGroup: path.length > 1 ? true : isGroup, isHidden: isHidden, category: category);
            return lookup(parent.children[$-1], path[1..$]);
        }

        return lookup(rootNode, urlSafeIdPath);
    }

    Node* getOrNullByIdPath(string[] urlSafeIdPath)
    in(urlSafeIdPath.length > 0, "id path must have at least 1 item")
    {
        Node* lookup(ref Node parent, string[] path)
        {
            if(path.length == 0)
                return &parent;

            foreach(ref child; parent.children)
            {
                if(child.urlSafeId == path[0])
                    return lookup(child, path[1..$]);
            }

            return null;
        }

        auto fromVisibleTree = lookup(this.rootNode, urlSafeIdPath);
        return (fromVisibleTree is null)
            ? lookup(this.nonVisibleRootNode, urlSafeIdPath)
            : fromVisibleTree;
    }
}

@JsonType("R")
struct ApiPageRoot
{
    @JsonType("sh")
    static struct SidebarHeader
    {
        @JsonField("i") string targetHtmlId;
        @JsonField("t") string text;
        @JsonField("l") uint nestingLevel;
    }

    @JsonField("t") string title;
    @JsonField("c") ApiPageComponent[] components;
    @JsonField("h") SidebarHeader[] sidebarHeaders;

    void add(ComponentT)(ComponentT component)
    if(!is(ComponentT : _[], _))
    {
        this.components ~= component.asComponent;
    }

    void add(ComponentT)(ComponentT[] components)
    {
        foreach(component; components)
            this.components ~= component.asComponent;
    }
}

/++ Api page components ++/

alias ApiPageComponent = SumType!(
    ApiPageHeader,
    ApiPageSpan,
    ApiPageParagraph,
    ApiPageTable,
    ApiPageList,
    ApiPageDlangCode,
    ApiPageLink!ApiPageSpan,
);
ApiPageComponent asComponent(ComponentT)(ComponentT component)
{
    static if(is(ComponentT == ApiPageComponent))
        return component;
    else
        return ApiPageComponent(component);
}

alias ApiPageLink(InnerT) = SumType!(
    ApiPageNavLink!InnerT,
    ApiPageHrefLink!InnerT,
);

ApiPageComponent asHrefLink(ApiPageSpan span, string href) => ApiPageLink!ApiPageSpan(
    ApiPageHrefLink!ApiPageSpan(
        span,
        href
    )
).asComponent;

ApiPageComponent asNavLink(ApiPageSpan span, string[] idPath) => ApiPageLink!ApiPageSpan(
    ApiPageNavLink!ApiPageSpan(
        span,
        idPath
    )
).asComponent;

ApiPageDlangCodeComponent asHrefLink(ApiPageCodeText span, string href) => ApiPageLink!ApiPageCodeText(
    ApiPageHrefLink!ApiPageCodeText(
        span,
        href
    )
).asCodeComponent;

ApiPageDlangCodeComponent asNavLink(ApiPageCodeText span, string[] idPath) => ApiPageLink!ApiPageCodeText(
    ApiPageNavLink!ApiPageCodeText(
        span,
        idPath
    )
).asCodeComponent;

alias ApiPageDlangCodeComponent = SumType!(
    ApiPageCodeText,
    ApiPageLink!ApiPageCodeText,
    ApiPageCodeIndent,
    ApiPageCodeDedent,
    ApiPageCodeNewLine,
);
ApiPageDlangCodeComponent asCodeComponent(ComponentT)(ComponentT component)
{
    static if(is(ComponentT == ApiPageDlangCodeComponent))
        return component;
    else
        return ApiPageDlangCodeComponent(component);
}

@JsonType("ln")
struct ApiPageNavLink(InnerT)
{
    @JsonField("i") InnerT inner;
    @JsonField("p") string[] navIdPath;
}

@JsonType("lh")
struct ApiPageHrefLink(InnerT)
{
    @JsonField("i") InnerT inner;
    @JsonField("p") string href;
}

@JsonType("ph")
struct ApiPageHeader
{
    @JsonField("l") uint level;
    @JsonField("i") string htmlId;
    @JsonField("t") string text;
    // fam
}

@JsonType("ps")
struct ApiPageSpan
{
    enum Style
    {
        FAILSAFE = "FAILSAFE",
        bold = "b",
        italic = "i",
        code = "c"
    }

    @JsonField("s") Style[] style;
    @JsonField("t") string text;
}

@JsonType("pp")
struct ApiPageParagraph
{
    @JsonField("c") ApiPageComponent[] components;
}

@JsonType("pt")
struct ApiPageTable
{
    @JsonType("c") ApiPageComponent[] columns;
    @JsonType("r") ApiPageComponent[][] rows;
}

@JsonType("pl")
struct ApiPageList
{
    @JsonField("o") bool isOrdered;
    @JsonField("i") ApiPageComponent[] items; // Use nested ApiPageList for multi-depth lists.
    // m8
}

@JsonType("Pl")
struct ApiPageParamList
{
    alias TypeName = SumType!(ApiPageSpan, ApiPageLink!ApiPageSpan);

    @JsonType("P")
    static struct Param
    {
        @JsonField("n") ApiPageSpan name;
        @JsonField("t") TypeName typeName;
        @JsonField("d") ApiPageParagraph description;
    }

    @JsonField("p") Param[] params;
}

@JsonType("pd")
struct ApiPageDlangCode
{
    @JsonField("c") ApiPageDlangCodeComponent[] components;

    void add(ComponentT)(ComponentT component)
    if(!is(ComponentT : _[], _))
    {
        this.components ~= component.asCodeComponent;
    }

    void add(ComponentT)(ComponentT[] components)
    {
        foreach(component; components)
            this.components ~= component.asCodeComponent;
    }
}

@JsonType("t")
struct ApiPageCodeText
{
    enum Syntax
    {
        none = "n",
        keyword = "k",
        operator = "o",
        symbol = "s",
        expression = "e",
        comment = "c",
    }

    @JsonField("s") Syntax syntax;
    @JsonField("t") string text;
}

@JsonType("i")
struct ApiPageCodeIndent{}

@JsonType("d")
struct ApiPageCodeDedent{}

@JsonType("l")
struct ApiPageCodeNewLine {}