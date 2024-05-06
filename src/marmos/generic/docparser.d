/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.generic.docparser;

import std.typecons : Nullable, nullable;
import marmos.generic.model;

private struct DocParseContext
{
    string comment;
    size_t cursor;
    uint baseIndent;
}

private struct LineInfo
{
    string line;
    uint prefixWhitespace;
    bool isBaseAligned;
}

DocComment parseDocComment(string comment)
{
    DocComment result;
    debug result.sections ~= DocCommentSection("__debug",[
        DocCommentBlock(DocCommentParagraphBlock([
            DocCommentInline(DocCommentTextInline(comment))
        ]))
    ]);

    while(comment.length > 0 && (comment[0] == '\n' || comment[0] == '\r'))
        comment = comment[1..$];

    auto context = DocParseContext(comment, 0, determineBaseIndent(comment));

    DocCommentSection currentSection;
    currentSection.title = "__default";

    while(context.cursor < context.comment.length)
    {
        const line = readGenericLine(context); // Makes each line O(2n) at least, but it probably doesn't matter
        auto section = trySection(line);
        if(!section.isNull)
        {
            result.sections ~= currentSection;
            currentSection = section.get;
            continue;
        }
        else
        {
            auto block = tryBlock(context, line);
            if(!block.isNull)
            {
                currentSection.blocks ~= block.get;
                continue;
            }
        }
    }

    if(currentSection != DocCommentSection.init)
        result.sections ~= currentSection;

    return result;
}

private:

uint determineBaseIndent(string text)
{
    import std.utf : decode;
    import std.uni : isWhite;

    uint indent;
    size_t cursor;

    while(cursor < text.length && text[cursor] != '\n' && decode(text, cursor).isWhite)
        indent = cast(uint)cursor;

    return indent;
}

bool skipBaseIndent(scope ref DocParseContext context)
{
    import std.utf : decode;
    import std.uni : isWhite;

    const start = context.cursor;
    while(
        context.cursor < context.comment.length
        && context.cursor - start < context.baseIndent
        && context.comment[context.cursor] != '\n'
    ) 
    {
        auto peekCursor = context.cursor;
        if(decode(context.comment, peekCursor).isWhite)
        {
            context.cursor = peekCursor;
            continue;
        }
        break;
    }

    return (context.cursor - start) == context.baseIndent;
}

uint skipPrefixWhitespace(scope ref DocParseContext context)
{
    import std.utf : decode;
    import std.uni : isWhite;

    const start = context.cursor;
    while(
        context.cursor < context.comment.length
        && context.comment[context.cursor] != '\n'
    )
    {
        auto peekCursor = context.cursor;
        if(decode(context.comment, peekCursor).isWhite)
        {
            context.cursor = peekCursor;
            continue;
        }
        break;
    }

    return cast(uint)(context.cursor - start);
}

string readLine(scope ref DocParseContext context)
{
    // Edge case: newline
    if(
        context.cursor < context.comment.length 
        && context.comment[context.cursor] == '\n'
    )
    {
        context.cursor++;
        return "\n";
    }

    // Read up to the next newline
    const start = context.cursor;
    while(
        context.cursor < context.comment.length
        && context.comment[context.cursor] != '\n'
    ) { context.cursor++; }

    auto slice = context.comment[start..context.cursor];
    if(context.cursor < context.comment.length && context.comment[context.cursor] == '\n')
        context.cursor++; // Skip newline

    // Trim trailing whitespace
    while(slice.length > 0 && (
        slice[$-1] == '\n' || slice[$-1] == '\r' || slice[$-1] == '\t' || slice[$-1] == ' '
    )) { slice = slice[0..$-1]; }
    return slice;
}

LineInfo readGenericLine(scope ref DocParseContext context)
{
    LineInfo info;
    info.isBaseAligned = skipBaseIndent(context);
    info.prefixWhitespace = skipPrefixWhitespace(context);
    info.line = readLine(context);

    return info;
}

Nullable!DocCommentSection trySection(LineInfo info)
{
    if(info.line.length == 0 || info.line[$-1] != ':' || !info.isBaseAligned || info.prefixWhitespace > 0)
        return typeof(return).init;

    return DocCommentSection(info.line[0..$-1]).nullable;
}

Nullable!DocCommentBlock tryBlock(ref DocParseContext context, LineInfo info)
{
    if(info.line.length == 0 || info.line == "\n")
        return typeof(return).init;

    switch(info.line[0])
    {
        case '0': .. case '9':
            auto block = tryOrderedListBlock(context, info);
            if(!block.isNull)
                return DocCommentBlock(block.get).nullable;
            goto default;

        default: return DocCommentBlock(nextParagraphBlock(context, info)).nullable;
    }
}

DocCommentParagraphBlock nextParagraphBlock(ref DocParseContext context, LineInfo info)
{
    DocCommentParagraphBlock block;

    auto oldContext = context;
    while(info.line.length > 0 && info.line != "\n")
    {
        block.inlines ~= parseInlines(info);
        oldContext = context;
        info = readGenericLine(context);
    }

    return block;
}

Nullable!DocCommentOrderedListBlock tryOrderedListBlock(ref DocParseContext context, LineInfo info)
{
    import std.uni   : isNumber, isWhite;
    import std.utf   : decode;
    import std.conv  : to;

    enum LineType
    {
        FAILSAFE,
        isNewItem,
        isNewNestedItem,
        isContinuation,
        isEmpty,
        isNotPartOfList
    }

    uint extraIndent = info.prefixWhitespace;
    LineType getLineType(LineInfo info, ref size_t cursor)
    {
        if(info.line.length == 0 || info.line == "\n")
            return LineType.isEmpty;
        else if(info.prefixWhitespace < extraIndent || !info.isBaseAligned)
            return LineType.isNotPartOfList;
        else if(cursor >= info.line.length)
            return LineType.isEmpty;

        if(info.prefixWhitespace > extraIndent)
        {
            // See if we can treat the line as a new item instead.
            size_t copyCursor = 0;
            auto infoCopy = info;
            infoCopy.prefixWhitespace = extraIndent;
            if(getLineType(infoCopy, copyCursor) == LineType.isNewItem)
            {
                cursor = copyCursor;
                return LineType.isNewNestedItem;
            }
            return LineType.isContinuation;
        }

        // Check if the line starts with digits and dots, followed by whitespace
        while(cursor < info.line.length)
        {
            auto ch = decode(info.line, cursor);
            if(!ch.isNumber && ch != '.')
            {
                if(!ch.isWhite)
                    return LineType.isNotPartOfList;
                break;
            }
        }

        // Trim leading whitespace, as parseInlines semi-expects it to be gone
        while(cursor < info.line.length)
        {
            auto oldCursor = cursor;
            if(!decode(info.line, cursor).isWhite)
            {
                cursor = oldCursor;
                break;
            }
        }

        return LineType.isNewItem;
    }

    typeof(return) result;
    DocCommentOrderedListBlock.Item item;

    void push()
    {
        if(item.block.inlines.length > 0)
        {
            if(result.isNull)
                result = DocCommentOrderedListBlock();
            result.get.items ~= item;
            item = DocCommentOrderedListBlock.Item();
        }
    }

    while(info.line.length > 0)
    {
        size_t cursor;
        const lineType = getLineType(info, cursor);

        final switch(lineType) with(LineType)
        {
            case FAILSAFE: assert(false);
            case isEmpty: break;

            case isNewNestedItem:
            case isNewItem:
                push();
                info.line = info.line[cursor..$];
                item.block = DocCommentParagraphBlock(parseInlines(info));
                item.isNested = (lineType == isNewNestedItem);
                break;

            case isContinuation:
                item.block.inlines ~= parseInlines(info);
                break;

            case isNotPartOfList:
                push();
                return result;

        }

        info = readGenericLine(context);
    }
    push();

    return result;
}

DocCommentInline[] parseInlines(LineInfo info)
{
    import std.uni : isWhite;
    import std.utf : decode;

    DocCommentInline[] inlines;

    size_t start;
    size_t cursor;
    size_t beforeCursor;
    dchar grammarChar;

    void push(InlineT)(bool trimEnd = false)
    {
        // Whitespace can be included in the prefix, so we need to trim it.
        auto oldStart = start;
        while(start < beforeCursor && decode(info.line, start).isWhite)
            oldStart = start;
        start = oldStart;

        // Whitespace can be included in the suffix after reading a grammar character
        // so we need to trim it if signaled.
        if(trimEnd && beforeCursor > 0 && beforeCursor != start)
            beforeCursor--;

        // Then we can push the inline
        if(start < beforeCursor)
            inlines ~= DocCommentInline(InlineT(info.line[start..beforeCursor]));
        start = cursor;
        grammarChar = dchar.init;
    }

    bool lastWasSpace = true; // Edge case: Must start true to handle when the first character is a grammar character
    while(cursor < info.line.length)
    {
        beforeCursor = cursor;
        const ch = decode(info.line, cursor);
        switch(ch)
        {
            case '*':
                if(grammarChar == dchar.init && lastWasSpace)
                {
                    push!DocCommentTextInline(true);
                    grammarChar = ch;
                }
                else if(grammarChar == '*')
                    push!DocCommentBoldInline();
                break; // Don't interpret as a grammar character

            case '_':
                if(grammarChar == dchar.init && lastWasSpace)
                {
                    push!DocCommentTextInline(true);
                    grammarChar = ch;
                }
                else if(grammarChar == '_')
                    push!DocCommentItalicInline();
                break; // Don't interpret as a grammar character

            case '`':
                if(grammarChar == dchar.init && lastWasSpace)
                {
                    push!DocCommentTextInline(true);
                    grammarChar = ch;
                }
                else if(grammarChar == '`')
                    push!DocCommentCodeInline();
                break; // Don't interpret as a grammar character

            default:break;
        }
        lastWasSpace = ch.isWhite;
    }
    beforeCursor = cursor;
    push!DocCommentTextInline();

    return inlines;
}