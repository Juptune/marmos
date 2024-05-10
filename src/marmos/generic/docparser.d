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

private enum ListLineType
{
    FAILSAFE,
    isNewItem,
    isNewNestedItem,
    isContinuation,
    isEmpty,
    isNotPartOfList
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
            const isFreshSection = (currentSection.blocks.length == 0);
            auto block = tryBlock(context, line, isFreshSection);
            if(!block.isNull)
            {
                currentSection.blocks ~= block.get;
                continue;
            }
        }
    }

    if(currentSection.blocks.length > 0)
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

Nullable!DocCommentBlock tryBlock(ref DocParseContext context, LineInfo info, bool isFreshSection)
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

        case '-':
        case '*':
            auto block = tryUnorderedListBlock(context, info);
            if(!block.isNull)
                return DocCommentBlock(block.get).nullable;
            goto default;

        default:
            if(isFreshSection)
            {
                auto block = tryEqualListBlock(context, info);
                if(!block.isNull)
                    return DocCommentBlock(block.get).nullable;
            }
            return DocCommentBlock(nextParagraphBlock(context, info)).nullable;
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
    import std.uni : isNumber, isWhite;
    import std.utf : decode;

    uint extraIndent = info.prefixWhitespace;
    ListLineType getLineType(LineInfo info, ref size_t cursor)
    {
        if(info.line.length == 0 || info.line == "\n")
            return ListLineType.isEmpty;
        else if(info.prefixWhitespace < extraIndent || !info.isBaseAligned)
            return ListLineType.isNotPartOfList;
        else if(cursor >= info.line.length)
            return ListLineType.isEmpty;

        if(info.prefixWhitespace > extraIndent)
        {
            // See if we can treat the line as a new item instead.
            size_t copyCursor = 0;
            auto infoCopy = info;
            infoCopy.prefixWhitespace = extraIndent;
            if(getLineType(infoCopy, copyCursor) == ListLineType.isNewItem)
            {
                cursor = copyCursor;
                return ListLineType.isNewNestedItem;
            }
            return ListLineType.isContinuation;
        }

        // Check if the line starts with digits and dots, followed by whitespace
        while(cursor < info.line.length)
        {
            auto ch = decode(info.line, cursor);
            if(!ch.isNumber && ch != '.')
            {
                if(!ch.isWhite)
                    return ListLineType.isNotPartOfList;
                break;
            }
        }

        return ListLineType.isNewItem;
    }

    return tryListBlock!(DocCommentOrderedListBlock, DocCommentOrderedListBlock.Item)(context, info, &getLineType);
}

Nullable!DocCommentUnorderedListBlock tryUnorderedListBlock(ref DocParseContext context, LineInfo info)
{
    import std.uni : isNumber, isWhite;
    import std.utf : decode;

    uint extraIndent = info.prefixWhitespace;
    ListLineType getLineType(LineInfo info, ref size_t cursor)
    {
        if(info.line.length == 0 || info.line == "\n")
            return ListLineType.isEmpty;
        else if(info.prefixWhitespace < extraIndent || !info.isBaseAligned)
            return ListLineType.isNotPartOfList;
        else if(cursor >= info.line.length)
            return ListLineType.isEmpty;

        if(info.prefixWhitespace > extraIndent)
        {
            // See if we can treat the line as a new item instead.
            size_t copyCursor = 0;
            auto infoCopy = info;
            infoCopy.prefixWhitespace = extraIndent;
            if(getLineType(infoCopy, copyCursor) == ListLineType.isNewItem)
            {
                cursor = copyCursor;
                return ListLineType.isNewNestedItem;
            }
            return ListLineType.isContinuation;
        }

        // Check if the line starts with a bullet point or hyphen, followed by whitespace
        if(cursor >= info.line.length)
            return ListLineType.isEmpty;
        auto ch = decode(info.line, cursor);
        if(ch != '-' && ch != '*')
            return ListLineType.isNotPartOfList;

        if(cursor >= info.line.length)
            return ListLineType.isNotPartOfList;
        ch = decode(info.line, cursor);
        if(!ch.isWhite)
            return ListLineType.isNotPartOfList;

        return ListLineType.isNewItem;
    }

    return tryListBlock!(DocCommentUnorderedListBlock, DocCommentUnorderedListBlock.Item)(context, info, &getLineType);
}

Nullable!DocCommentEqualListBlock tryEqualListBlock(ref DocParseContext context, LineInfo info)
{
    import std.uni : isAlphaNum, isWhite;
    import std.utf : decode;

    uint extraIndent = info.prefixWhitespace;
    ListLineType getLineType(LineInfo info, ref size_t cursor, out string paramKey)
    {
        if(info.line.length == 0 || info.line == "\n")
            return ListLineType.isEmpty;
        else if(info.prefixWhitespace < extraIndent || !info.isBaseAligned)
            return ListLineType.isNotPartOfList;
        else if(cursor >= info.line.length)
            return ListLineType.isEmpty;

        if(info.prefixWhitespace > extraIndent)
            return ListLineType.isContinuation;

        // Read until the first whitespace character; consume the whitespace, then check if the next character is a '='
        enum State { reading, whitespace }
        State state = State.reading;

        while(cursor < info.line.length)
        {
            const endCursor = cursor;
            auto ch = decode(info.line, cursor);
            
            final switch(state) with(State)
            {
                case reading:
                    if(ch.isWhite)
                    {
                        state = State.whitespace;
                        paramKey = info.line[0..endCursor];
                    }
                    else if(!ch.isAlphaNum)
                        return ListLineType.isNotPartOfList;
                    break;

                case whitespace:
                    if(ch == '=')
                        return ListLineType.isNewItem;
                    else if(!ch.isWhite)
                        return ListLineType.isNotPartOfList;
                    break;
            }
        }
        if(cursor >= info.line.length)
            return ListLineType.isNotPartOfList;

        return ListLineType.isNewItem;
    }

    typeof(return) result;
    DocCommentParagraphBlock item;
    string paramKey;

    void push()
    {
        if(item.inlines.length > 0)
        {
            if(result.isNull)
                result = DocCommentEqualListBlock();
            result.get.items ~= DocCommentEqualListBlock.Item(paramKey, item);
            item = DocCommentParagraphBlock();
        }
    }

    while(info.line.length > 0)
    {
        size_t cursor;
        string newParamKey;
        const lineType = getLineType(info, cursor, newParamKey);

        final switch(lineType) with(ListLineType)
        {
            case FAILSAFE: assert(false);
            case isEmpty: break;

            case isNewNestedItem:
            case isNewItem:
                push();
                info.line = info.line[cursor..$];
                item = DocCommentParagraphBlock(parseInlines(info));
                paramKey = newParamKey;
                break;

            case isContinuation:
                item.inlines ~= parseInlines(info);
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

Nullable!ListT tryListBlock(ListT, ListItemT)(
    ref DocParseContext context, 
    LineInfo info,
    ListLineType delegate(LineInfo info, ref size_t cursor) getLineType,
)
{
    typeof(return) result;
    ListItemT item;

    void push()
    {
        if(item.block.inlines.length > 0)
        {
            if(result.isNull)
                result = ListT();
            result.get.items ~= item;
            item = ListItemT();
        }
    }

    while(info.line.length > 0)
    {
        size_t cursor;
        const lineType = getLineType(info, cursor);

        final switch(lineType) with(ListLineType)
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

            default: break;
        }
        lastWasSpace = ch.isWhite;
    }
    beforeCursor = cursor;
    push!DocCommentTextInline();

    return inlines;
}