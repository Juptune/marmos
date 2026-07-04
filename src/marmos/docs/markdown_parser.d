/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.docs.markdown_parser;

import std.exception : enforce;
import std.typecons : Nullable;

import marmos.docs.markdown_models;
import std.algorithm.comparison; // Intentionally everything

MarkdownRoot parseMarkdown(string text)
{
    import std.algorithm : startsWith;

    MarkdownRoot root;
    size_t cursor;

    /+
        Metadata in our Markdown format looks like this:

        ---
        key1: value1
        key2: value2
        so on: so forth
        ---
        # This is the start

        Of my markdown content!
    +/
    const hasMetadata = text.startsWith("---\n");
    if(hasMetadata)
        root.metadata = parseMetadata(text, cursor);

    while(true)
    {
        auto container = nextContainer(text, cursor);
        if(container.isNull)
            break;
        root.containers ~= container.get;
    }

    return root;
}

private MarkdownMetadata parseMetadata(string text, scope ref size_t cursor)
{
    import std.algorithm : startsWith;
    import std.exception : enforce;

    MarkdownMetadata metadata;

    // Skip "---\n"
    cursor += "---\n".length;

    while(text[cursor..$].startsWith("---\n")) // Keep reading lines until we find the closing ---
    {
        enforce(cursor < text.length, "unexpected EOF when parsing markdown metadata");

        // Special case: Ignore blank lines
        if(text[cursor] == '\n')
        {
            cursor++;
            continue;
        }

        // Read until ':'
        const keyStart = cursor;
        while(cursor < text.length && text[cursor] != ':')
            cursor++;
        enforce(cursor < text.length, "unexpected EOF when reading metadata key");
        const keyEnd = cursor;

        // Skip ':' and any whitespace
        while(cursor < text.length && (text[cursor] == ':' || text[cursor] == ' '))
            cursor++;
        enforce(cursor < text.length, "unexpected EOF when preparing to read metadata value");

        // Read until the end of the line
        const valueStart = cursor;
        while(cursor < text.length && text[cursor] != '\n')
            cursor++;
        enforce(cursor < text.length, "unexpected EOF when reading metadata value");
        
        auto valueEnd = cursor;
        while(valueEnd > valueStart && text[valueEnd] == ' ')
            valueEnd--;

        // Skip new line
        cursor++;

        metadata.keyValuePairs[text[keyStart..keyEnd]] = text[valueStart..valueEnd];
    }

    return metadata;
}

/++ Helpers ++/

private void skipEmptyLines(string text, scope ref size_t cursor)
{
    while(cursor < text.length && text[cursor] == '\n')
        cursor++;
}

private void skipSpaces(string text, scope ref size_t cursor)
{
    while(cursor < text.length && text[cursor] == ' ')
        cursor++;
}

private size_t consumeAndCountSpaces(string text, scope ref size_t cursor)
{
    const start = cursor;
    while(cursor < text.length && text[cursor] == ' ')
        cursor++;
    
    return cursor - start;
}

/++ Container parsing ++/

private Nullable!MarkdownContainer nextContainer(string text, scope ref size_t cursor)
{
    import std.ascii : isDigit;

    skipEmptyLines(text, cursor);

    const spacePrefixCount = consumeAndCountSpaces(text, cursor);

    if(cursor >= text.length)
        return typeof(return).init;

    const peek = text[cursor];
    const peek2 = (cursor + 1 >= text.length) ? char.init : text[cursor + 1];
    const peek3 = (cursor + 2 >= text.length) ? char.init : text[cursor + 2];

    if(peek == '#' && spacePrefixCount == 0)
        return typeof(return)(MarkdownContainer(nextHeader(text, cursor, spacePrefixCount)));
    else if(peek == '*' || peek == '-' || (peek == '1' && peek2 == '.') || (peek == 'a' && peek2 == '.'))
        return typeof(return)(MarkdownContainer(nextListItem(text, cursor, spacePrefixCount)));
    else if(peek == '`' && peek2 == '`' && peek3 == '`' && spacePrefixCount == 0)
        return typeof(return)(MarkdownContainer(nextCodeBlock(text, cursor)));

    return typeof(return)(MarkdownContainer(nextParagraph(text, cursor, spacePrefixCount)));
}

private MarkdownHeader nextHeader(string text, scope ref size_t cursor, size_t spacePrefixCount)
{
    uint level;
    while(cursor < text.length && text[cursor] == '#')
    {
        level++;
        cursor++;
    }

    auto paragraph = nextParagraph(text, cursor, spacePrefixCount);
    return MarkdownHeader(level, paragraph);
}

private MarkdownListItem nextListItem(string text, scope ref size_t cursor, size_t spacePrefixCount)
{
    import std.ascii : isDigit;

    const level = spacePrefixCount / 2;
    const isOrdered = isDigit(text[cursor]);

    if(isOrdered)
    {
        while(cursor < text.length && text[cursor] != '.')
            cursor++;
        cursor++; // Also skip the '.'
    }
    else
        cursor++; // Skip the '*' or '-'

    auto paragraph = nextParagraph(text, cursor, spacePrefixCount);
    return MarkdownListItem(isOrdered, cast(uint)level, paragraph);
}

private MarkdownCodeBlock nextCodeBlock(string text, scope ref size_t cursor)
{
    // Skip first ```
    cursor += 3;

    // We're not handling metadata _yet_, so enforce a new line
    enforce(cursor < text.length && text[cursor] == '\n', "Expected new line after opening code block");
    cursor++;

    const start = cursor;
    size_t end;
    while(cursor < text.length)
    {
        const prev = text[cursor-1];
        if(prev == '\n' && text[cursor] == '`')
        {
            enforce(cursor + 2 < text.length, "Unexpected EoF when reading closing of code block");
            if(text[cursor+1] == '`' && text[cursor+2] == '`')
            {
                end = cursor - 1; // Don't include the new line
                cursor += 3;
                break;
            }
        }

        cursor++;
    }

    return MarkdownCodeBlock("", text[start..end]);
}

private MarkdownParagraph nextParagraph(string text, scope ref size_t cursor, size_t spacePrefixCount)
{
    MarkdownInline[] inlines;

    while(cursor < text.length)
    {
        skipSpaces(text, cursor);

        if(cursor < text.length && text[cursor] == '\n')
        {
            cursor++;
            const cursorBeforeSkippingSpaces = cursor;
            skipSpaces(text, cursor);

            const peek = text[cursor];
            const peek2 = (cursor + 1 >= text.length) ? char.init : text[cursor + 1];
            const peek3 = (cursor + 2 >= text.length) ? char.init : text[cursor + 2];

            if(peek == '#' && spacePrefixCount == 0)
                break;
            else if(peek == '*' || peek == '-' || (peek == '1' && peek2 == '.') || (peek == 'a' && peek2 == '.'))
            {
                cursor = cursorBeforeSkippingSpaces; // Spaces are meaningful to the list parser, so preserve them.
                break;
            }
            else if(peek == '`' && peek2 == '`' && peek3 == '`' && spacePrefixCount == 0)
                break;
        }

        if(cursor < text.length && text[cursor] == '\n')
            break;

        inlines ~= nextInline(text, cursor);
    }

    return MarkdownParagraph(inlines);
}

/++ Inline parsing ++/

private MarkdownInline nextInline(string text, scope ref size_t cursor)
{
    skipSpaces(text, cursor);
    if(cursor >= text.length || text[cursor] == '\n')
        return typeof(return)(MarkdownPlainText(""));

    const peek = text[cursor];
    const peek2 = (cursor + 1 < text.length) ? text[cursor + 1] : char.init;

    enum Probably
    {
        plain,
        bold,
        italic,
        code,
        link,
    }

    auto probably = Probably.plain;

    if((peek == '*' && peek2 == '*') || (peek == '_' && peek2 == '_'))
        probably = Probably.bold;
    else if(peek == '*' || peek == '_')
        probably = Probably.italic;
    else if(peek == '`')
        probably = Probably.code;
    else if(peek == '[')
        probably = Probably.link;

    string linkText; // Needs to be preserved when parsing links
    size_t linkUrlStart;

    // NOTE: Nested inlines aren't actually supported... at least for now, even though the model technically allows for it.
    const start = cursor;
    cursor++;
    while(cursor < text.length)
    {
        const ch = text[cursor];
        if(ch == '\n')
            return typeof(return)(MarkdownPlainText(text[start..cursor]));

        final switch(probably) with(Probably)
        {
            case plain:
                // If we hit something that _could_ be a different inline, return what we've read in so far
                if(ch == '*' || ch == '_' || ch == '`' || ch == '[')
                    return typeof(return)(MarkdownPlainText(text[start..cursor]));
                cursor++;
                break;

            case link:
                if(linkText.length == 0)
                {
                    const peekAfterCh = (cursor + 1 < text.length) ? text[cursor + 1] : char.init;
                    if(ch == ']' && peekAfterCh == '(')
                    {
                        const actualStart = start + 1; // Skip the starter char
                        linkText = text[actualStart..cursor];
                        cursor += 2; // Skip the text terminator, and the link starter char
                        linkUrlStart = cursor;
                    }
                    else
                        cursor++;
                }
                else
                {
                    if(ch == ')')
                    {
                        const slice = text[linkUrlStart..cursor];
                        cursor++;
                        return typeof(return)(MarkdownLink(linkText, slice));
                    }
                    else
                        cursor++;
                }
                break;

            // Not really worth DRYing these cases honestly, not enough duplication to care.
            case bold:
                const peekAfterCh = (cursor + 1 < text.length) ? text[cursor + 1] : char.init;
                if(ch == peek && peekAfterCh == peek2)
                {
                    const actualStart = start + 2; // Skip the two starter chars
                    const slice = text[actualStart..cursor];
                    cursor += 2; // Skip the two terminator chars

                    auto inner = new MarkdownInline(MarkdownPlainText(slice));
                    return typeof(return)(MarkdownBoldText(inner));
                }
                else
                    cursor++;
                break;

            case italic:
                if(ch == peek)
                {
                    const actualStart = start + 1; // Skip the first starter char
                    const slice = text[actualStart..cursor];
                    cursor++; // Skip the terminator char

                    auto inner = new MarkdownInline(MarkdownPlainText(slice));
                    return typeof(return)(MarkdownItalicText(inner));
                }
                else
                    cursor++;
                break;

            case code:
                if(ch == peek)
                {
                    const actualStart = start + 1; // Skip the first starter char
                    const slice = text[actualStart..cursor];
                    cursor++; // Skip the terminator char

                    auto inner = new MarkdownInline(MarkdownPlainText(slice));
                    return typeof(return)(MarkdownCodeText(inner));
                }
                else
                    cursor++;
                break;
        }
    }

    // We should've returned by this point unless we've hit EOF, so just return the entire thing.
    assert(cursor == text.length);
    return typeof(return)(MarkdownPlainText(text[start..cursor]));
}