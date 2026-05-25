/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.docs.html_generator;

import std.algorithm    : map;
import std.array        : array;
import std.logger       : infof, warningf;
import std.sumtype      : SumType, match;

import marmos.docs.discover : SiteRoot, StagingRootGroup, StagingApiRefGroup, loadJsonModel;
import marmos.docs.staging_models; // Intentionally everything

void generateSite(SiteRoot site)
{
    emitStaticFiles(site);

    foreach(group; site.stagingRootGroups)
    {
        if(auto apiRefGroup = cast(StagingApiRefGroup)group)
            generateAndEmitApiRefGroup(site, apiRefGroup);
        else
            assert(false, "Unhandled staging type?");
    }
}

/++ Generators ++/

private void generateAndEmitApiRefGroup(SiteRoot site, StagingApiRefGroup group)
{
    infof("[%s] generating as API Reference group", group.groupName);

    foreach(name, version_; group.versionsByName)
    {
        foreach(page; version_.pages)
            generateAndEmitApiRefPage(site, group, version_, page);
    }
}

private void generateAndEmitApiRefPage(SiteRoot site, StagingApiRefGroup group, StagingApiRefGroup.Version version_, StagingApiRefGroup.Page page)
{
    infof("[%s] generating page from model at %s", group.groupName, page.sourceModelPath);

    auto pageModel = loadJsonModel!ApiPageRoot(page.sourceModelPath);
    auto html = mainTemplate(
        site,
        body: () => bodyWithSidebars(
            leftSidebar: () => buildApiRefLeftSidebar(site, group, version_, page),
            rightSidebar: () => Html(tag: "div"),
            body: () => buildApiRefBody(site, group, version_, page, pageModel),
        )
    );
    emitFile(site, page.htmlOutputSubpath, render(html));
}

private void emitStaticFiles(SiteRoot site)
{
    emitFile(site, site.apiRefGroupToggleJsPath, cast(string)import("mardocs/js/api-reference/group-toggle.js"));
}

/++ API Reference builders ++/

private Html buildApiRefLeftSidebar(SiteRoot site, StagingApiRefGroup group, StagingApiRefGroup.Version version_, StagingApiRefGroup.Page page)
{
    import std.algorithm : filter;
    import std.range     : walkLength;

    // Find the node path for this page
    GroupNavRoot.Node[] findNodePath(GroupNavRoot.Node currentNode, GroupNavRoot.Node[] nodePath)
    {
        foreach(child; currentNode.children)
        {
            if(child.href.length == 0)
            {
                auto result = findNodePath(child, nodePath ~ child);
                if(result.length > 0)
                    return result;
                continue;
            }

            const withoutLeadingSlash = child.href[1..$] ~ "/index.html";
            if(withoutLeadingSlash == page.htmlOutputSubpath)
                return nodePath ~ child;
        }

        return null;
    }
    auto nodePath = findNodePath(version_.navRoot.rootNode, []);

    // Generate the nav list HTML
    Html itemWrapper(Html inner) => Html(tag: "div", classes: ["flex"], content: inner);
    string nameOf(GroupNavRoot.Node node) => (node.userFacingName.length == 0) ? node.urlSafeId : node.userFacingName;

    Html generateNavList(GroupNavRoot.Node node, size_t depth)
    in(node.isGroup)
    {
        import std.algorithm : sort;
        import std.conv      : to;

        const isPartOfNodePath = (depth < nodePath.length) && nodePath[depth] == node;
        
        // Setup the nav list order as:
        //  1. Overview
        //  2. Submodules (alphabetical)
        //  3. Everything else (alphabetical)
        GroupNavRoot.Node overview;
        GroupNavRoot.Node[] submodules;
        GroupNavRoot.Node[] everythingElse;

        foreach(child; node.children)
        {
            if(child.urlSafeId == site.groupNavIndexId)
                overview = child;
            else if(child.isGroup && child.category == GroupNavRoot.Node.Category.module_)
                submodules ~= child;
            else
                everythingElse ~= child;
        }
        submodules.sort!((a,b) => nameOf(a) < nameOf(b));
        everythingElse.sort!((a,b) => nameOf(a) < nameOf(b));

        auto children = [overview] ~ submodules ~ everythingElse;

        return Html(tag: "div", classes: ["flex", "flex-col"], attributes: [
            "data-type": "group", 
            "data-id": node.urlSafeId, 
            "data-category": node.category,
            "data-depth": depth.to!string,
        ], content: [
            // Name
            Html(tag: "div", classes: ["flex", "cursor-pointer", "hover:underline", "select-none"], content: [
                Html(tag: "span", classes: ["flex", isPartOfNodePath ? "font-bold" : "", "pr-1"], attributes: ["data-type": "chevron"], content: "v"),
                Html(tag: "span", classes: ["flex", isPartOfNodePath ? "font-bold" : ""], attributes: ["data-type": "name"], content: nameOf(node)),
            ]),

            // Children
            Html(
                tag: "div", 
                classes: ["flex", "flex-col", "pl-4"],
                attributes: ["data-type": "children"],
                content: children
                            .filter!(child => !child.isHidden) // Ignore hidden children
                            .filter!(child => !child.isGroup || child.children.filter!(c => !c.isHidden).walkLength > 0) // If a child is a group, then that group must have at least 1 visible child to be emitted
                            .map!((child) {
                                if(child.isGroup)
                                    return generateNavList(child, depth + 1);

                                return Html(tag: "div", classes: ["flex"], attributes: [
                                    "data-type": "leaf", 
                                    "data-id": child.urlSafeId, 
                                    "data-category": child.category
                                ], content: [
                                    Html(
                                        tag: "a", 
                                        classes: [
                                            "flex",
                                            "hover:underline",
                                            (depth + 1 < nodePath.length) && nodePath[depth + 1] == child ? "font-bold" : ""
                                        ], 
                                        attributes: ["href": child.href], 
                                        content: nameOf(child)
                                    )
                                ]);
                            }).array
            ),
        ]);
    }

    Html[] links;
    foreach(child; version_.navRoot.rootNode.children)
        links ~= generateNavList(child, depth: 0);

    return Html(
        // Wrapper
        tag: "div",
        classes: ["w-full", "h-full", "pt-4", "bg-gray-400"],
        content: [
            // Search bar
            Html(tag: "input", classes: ["w-9/10", "ml-4", "mb-4", "bg-white"], attributes: ["type": "text", "placeholder": "Search..."]),

            // Link list
            Html(tag: "div", classes: ["pl-4", "overflow-x-auto"], content: links),

            // Script for collapsing stuff
            Html(tag: "script", attributes: ["src": "/"~site.apiRefGroupToggleJsPath]),
        ],
    );
}

private Html buildApiRefBody(SiteRoot site, StagingApiRefGroup group, StagingApiRefGroup.Version version_, StagingApiRefGroup.Page page, ApiPageRoot pageModel)
{
    return Html(
        tag: "div",
        classes: [],
        content: pageModel.components.map!(comp => renderComponent(comp, version_.navRoot)).array,
    );
}

/++ Component rendering ++/

private Html renderComponent(ApiPageComponent sum, GroupNavRoot nav)
{
    import std.algorithm : canFind;
    import std.conv      : to;

    Html renderSpan(ApiPageSpan comp) => Html(
        tag: comp.style.canFind(ApiPageSpan.Style.code) ? "code" : "span",
        classes: comp.style.map!((style) {
            final switch(style) with(ApiPageSpan.Style)
            {
                case FAILSAFE: assert(false);
                case code: return ""; // Handled by the tag instead

                case bold: return "font-bold";
                case italic: return "italic";
            }
        }).array,
        content: comp.text,
    );

    return sum.match!(
        (ApiPageHeader comp) => Html(
            tag: "h"~comp.level.to!string, 
            classes: [],
            attributes: [
                "id": comp.htmlId
            ],
            content: comp.text
        ),
        (ApiPageSpan comp) => renderSpan(comp),
        (ApiPageParagraph comp) => Html(
            tag: "p",
            classes: [],
            content: comp.components.map!(c => renderComponent(c, nav)).array,
        ),
        (ApiPageTable comp) => Html(
            tag: "table",
            classes: [],
            content:
                // Headers
                [Html(
                    tag: "thead",
                    classes: [],
                    content: Html(
                        tag: "tr",
                        classes: [],
                        content: comp.columns.map!(col => Html(
                            tag: "th",
                            classes: [],
                            content: renderComponent(col, nav),
                        )).array
                    )
                )]
                // Rows
                ~ [Html(
                    tag: "tbody",
                    classes: [],
                    content: comp.rows.map!(row => Html(
                        tag: "tr",
                        classes: [],
                        content: row.map!(cell => Html(
                            tag: "td",
                            classes: [],
                            content: renderComponent(cell, nav),
                        )).array
                    )).array
                )]
        ),
        (ApiPageList comp) => Html(
            tag: comp.isOrdered ? "ol" : "ul",
            classes: [],
            content: comp.items.map!(c => Html(
                tag: "li",
                classes: [],
                content: renderComponent(c, nav),
            )).array,
        ),
        (ApiPageLink!ApiPageSpan comp) => Html(
            tag: "a",
            classes: [],
            attributes: [
                "href": comp.match!(
                    (ApiPageNavLink!ApiPageSpan link) {
                        auto node = nav.getOrNullByIdPath(link.navIdPath);
                        if(node is null)
                        {
                            warningf("failed to lookup nav link: %s", link.navIdPath);
                            return "ERROR_NOT_FOUND";
                        }

                        return node.href;
                    },
                    (ApiPageHrefLink!ApiPageSpan link) => link.href,
                )
            ],
            content: comp.match!(
                (link) => renderSpan(link.inner),
            )
        ),
        (ApiPageDlangCode comp) => renderCodeBlock(comp, nav),
    );
}

private Html renderCodeBlock(ApiPageDlangCode code, GroupNavRoot nav)
{
    import std.algorithm : filter;
    import std.conv      : to;
    import std.range     : walkLength, iota;

    static immutable CLASSES_FOR_SYNTAX = [
        ApiPageCodeText.Syntax.none: [""],
        ApiPageCodeText.Syntax.keyword: [""],
        ApiPageCodeText.Syntax.operator: [""],
        ApiPageCodeText.Syntax.symbol: [""],
        ApiPageCodeText.Syntax.expression: [""],
        ApiPageCodeText.Syntax.comment: [""],
    ];

    const lineCount = 1 + code.components.filter!(comp => comp.match!(
        (ApiPageCodeNewLine _) => true,
        (_) => false
    )).walkLength;

    bool firstForLine = true;
    uint indent = 0;

    Html renderText(ApiPageCodeText text) => Html(
        tag: "span",
        classes: [] ~ CLASSES_FOR_SYNTAX[text.syntax],
        content: text.text
    );

    Html renderComponent(ApiPageDlangCodeComponent sum) => sum.match!(
        (ApiPageCodeText comp) => renderText(comp),
        (ApiPageLink!ApiPageCodeText comp) => Html(
            tag: "a",
            attributes: [
                "href": comp.match!(
                    (ApiPageNavLink!ApiPageCodeText link) {
                        auto node = nav.getOrNullByIdPath(link.navIdPath);
                        if(node is null)
                        {
                            warningf("failed to lookup nav link: %s", link.navIdPath);
                            return "ERROR_NOT_FOUND";
                        }

                        return node.href;
                    },
                    (ApiPageHrefLink!ApiPageCodeText link) => link.href,
                )
            ],
            content: renderText(comp.match!(l => l.inner)),
        ),
        (ApiPageCodeIndent comp) {
            indent++;
            return Html(tag: "__raw", content: "");
        },
        (ApiPageCodeDedent comp) {
            assert(indent > 0, "bug: Too many dedents?");
            indent--;
            return Html(tag: "__raw", content: "");
        },
        (ApiPageCodeNewLine comp) {
            firstForLine = true;
            return Html(tag: "__raw", content: "\n");
        },
    );

    Html[] renderedComponents;
    foreach(sum; code.components)
    {
        const isIndentOrDedent = sum.match!(
            (ApiPageCodeIndent _) => true,
            (ApiPageCodeDedent _) => true,
            (_) => false,
        );

        if(firstForLine && !isIndentOrDedent)
        {
            string indentStr;
            foreach(i; 0..indent)
                indentStr ~= "    ";

            renderedComponents ~= Html(tag: "__raw", content: indentStr);
            firstForLine = false;
        }

        renderedComponents ~= renderComponent(sum);
    }

    return Html(
        tag: "code",
        classes: ["grid", "grid-cols-2"],
        attributes: [
            "style": "grid-template-columns: auto 1fr"
        ],
        content: [
            // Line numbers
            Html(
                tag: "div",
                classes: ["w-auto"],
                content: iota(0, lineCount).map!(i => Html(
                    tag: "div",
                    classes: [],
                    content: (i + 1).to!string
                )).array
            ),

            // Code
            Html(
                tag: "div",
                classes: [],
                content: Html(
                    tag: "pre",
                    classes: [],
                    content: renderedComponents
                )
            ),
        ],
    );
}

/++ HTML Builders ++/

private Html mainTemplate(
    SiteRoot site,
    scope Html delegate() body = null,
    scope Html[] delegate() head = null,
) => Html(
    tag: null, // Special
    content: [
        Html(
            tag: "head",
            content: [
                Html(tag: "meta", attributes: ["charset": "UTF-8"]),
                Html(tag: "meta", attributes: ["name": "viewport", "content": "width=device-width,initial-scale=1"]),
                Html(tag: "script", attributes: ["src": "https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"]),
            ]
            ~ (head is null ? [] : head())
        ),

        Html(
            tag: "body",
            content: [
                // Main wrapper
                Html(tag: "div", classes: ["w-full", "min-h-[100dvh]"], content: [
                    navbar(site),

                    // Body wrapper
                    Html(tag: "div", classes: ["w-full", "min-h-screen"], content: 
                        []
                        ~ (body is null ? [] : [body()])
                    ),
                ]),
            ],
        )
    ],
);

private Html navbar(
    SiteRoot site
) => Html(
    tag: "section",
    classes: ["grid", "grid-cols-3", "items-center", "w-full", "h-auto", "p-4", "bg-red-300"],
    content: [
        // Left section
        Html(tag: "div", content: [
            // Title
            Html(tag: "span", classes: ["text-lg"], content: site.config.siteTitle)
        ]),

        // Middle section
        Html(tag: "div", classes: ["flex", "justify-center"], content: [
            // Root group links
            Html(tag: "nav", classes: ["flex"], content: site.rootGroups.map!(group =>
                Html(tag: "a", attributes: ["href": "/"~group.groupUrlName], content: group.groupName)
            ).array)
        ]),
        
        // Right section
        Html(tag: "div"),
    ],
);

private Html bodyWithSidebars(
    scope Html delegate() leftSidebar,
    scope Html delegate() rightSidebar,
    scope Html delegate() body,
) => Html(
    tag: "div",
    classes: ["w-full", "min-h-screen", "grid", "grid-cols-10"],
    content: [
        Html(tag: "section", classes: ["w-full", "h-full", "col-span-2"], content: leftSidebar()),
        Html(tag: "section", classes: ["w-full", "h-full", "col-span-7"], content: body()),
        Html(tag: "section", classes: ["w-full", "h-full"], content: rightSidebar()),
    ]
);

/++ HTML Output ++/

private struct Html
{
    string tag;
    string[] classes;
    string[string] attributes;
    SumType!(Html[], string) content;

    this(string tag, string[] classes = [], string[string] attributes = null)
    {
        this.tag = tag;
        this.classes = classes;
        this.attributes = attributes;
    }

    this(string tag, typeof(content) content, string[] classes = [], string[string] attributes = null)
    {
        this.tag = tag;
        this.classes = classes;
        this.attributes = attributes;
        this.content = content;
    }

    this(string tag, Html[] content, string[] classes = [], string[string] attributes = null)
    {
        this.tag = tag;
        this.classes = classes;
        this.attributes = attributes;
        this.content = content;
    }

    this(string tag, string content, string[] classes = [], string[string] attributes = null)
    {
        this.tag = tag;
        this.classes = classes;
        this.attributes = attributes;
        this.content = content;
    }

    this(string tag, Html content, string[] classes = [], string[string] attributes = null)
    {
        this.tag = tag;
        this.classes = classes;
        this.attributes = attributes;
        this.content = [content];
    }
}

string render(Html root)
{
    import std.array        : Appender;
    import std.exception    : assumeUnique;

    Appender!(char[]) code;
    code.put("<!DOCTYPE html>\n");
    code.put("<html>\n");
    
    int noFormat = 0;
    void putIndent(uint amount) 
    { 
        if(noFormat > 0)
            return;

        foreach(i; 0..amount)
            code.put("  "); 
    }

    void putEscaped(string str)
    {
        // TODO
        code.put(str);
    }

    void put(Html html, uint indent)
    {
        if(html.tag == "__raw")
        {
            code.put(html.content.match!(
                (Html[] _) => "__ERROR__",
                (string str) => str
            ));
            return;
        }

        if(html.tag == "pre")
            noFormat++;
        scope(exit) if(html.tag == "pre")
            noFormat--;

        putIndent(indent);
        code.put('<');
        code.put(html.tag);
        if(html.classes.length > 0)
        {
            code.put(" class=\"");
            foreach(cls; html.classes)
            {
                code.put(' ');
                code.put(cls);
            }
            code.put('"');
        }
        foreach(name, value; html.attributes)
        {
            code.put(' ');
            code.put(name);
            code.put(`="`);
            putEscaped(value);
            code.put('"');
        }
        code.put(">");

        if(noFormat == 0)
            code.put('\n');

        html.content.match!(
            (Html[] children) { foreach(child; children) put(child, indent + 1); },
            (string text) { putEscaped(text); },
        );

        putIndent(indent);
        code.put("</");
        code.put(html.tag);
        code.put(">");

        if(noFormat == 0)
            code.put('\n');
    }
    
    root.content.match!(
        (Html[] children) { foreach(child; children) put(child, indent: 1); },
        (string _){},
    );

    code.put("</html>\n");
    return code.data.assumeUnique;
}

/++ File helpers ++/

private void emitFile(SiteRoot site, string subpath, const(char)[] text)
{
    import std.file : writeText = write, mkdirRecurse;
    import std.path : dirName, buildNormalizedPath;

    const path = buildNormalizedPath(site.buildDir, subpath);

    infof("emitting file: %s", path);

    mkdirRecurse(path.dirName);
    writeText(path, text);
}