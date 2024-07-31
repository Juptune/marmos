import { DocComment, DocCommentBlock, DocCommentBoldInline, DocCommentCodeInline, DocCommentEqualListBlock, DocCommentItalicInline, DocCommentLinkInline, DocCommentOrderedListBlock, DocCommentOrderedListBlockItem, DocCommentParagraphBlock, DocCommentSection, DocCommentTextInline, DocCommentUnorderedListBlock, DocCommentUnorderedListBlockItem } from "../../marmos.js";
import { DocfxBlock, DocfxList, DocfxParam, DocfxParams, MarkdownString } from "./model.js";

const DEFAULT_SECTION = "__default";

export type CommentConversionConfig = {
    lookupParameterType?: (name: string) => string | undefined
    createAboutHeader?: boolean
}

export function marmosCommentToDocfx(comment: DocComment, config: CommentConversionConfig): DocfxBlock[] {
    const blocks: DocfxBlock[] = [];

    for(const section of comment.sections) {
        for (const block of sectionToBlocks(section, config)) {
            blocks.push(block)
        }
    }

    return blocks
}

export function marmosCommentGetSummary(comment: DocComment): string {
    const defaultSection = comment.sections.find(s => s.title === DEFAULT_SECTION)
    if(defaultSection) {
        const paragraph = defaultSection.blocks.find(b => b.typename_ === DocCommentParagraphBlock.typename__)
        if(paragraph)
            return renderParagraphToMarkdown(paragraph as DocCommentParagraphBlock)
    }

    return ""
}

function sectionToBlocks(section: DocCommentSection, config: CommentConversionConfig): DocfxBlock[] {
    const blocks: DocfxBlock[] = [];

    if(section.title !== DEFAULT_SECTION)
        blocks.push({ h3: section.title })
    else if(config.createAboutHeader ?? true)
        blocks.push({ h2: "About" })

    for(const block of section.blocks) {
        blocks.push(convertBlockToDocfx(block, config))
    }

    return blocks
}

function convertBlockToDocfx(block: DocCommentBlock, config: CommentConversionConfig): DocfxBlock {
    switch(block.typename_) {
        case DocCommentParagraphBlock.typename__:
            return { markdown: renderParagraphToMarkdown(block as DocCommentParagraphBlock) }

        case DocCommentOrderedListBlock.typename__:
            return { markdown: renderListToMarkdown((block as DocCommentOrderedListBlock).items) }

        case DocCommentUnorderedListBlockItem.typename__:
            return { markdown: renderListToMarkdown((block as DocCommentUnorderedListBlock).items) }

        case DocCommentEqualListBlock.typename__:
            return convertParameterBlock(block as DocCommentEqualListBlock, config)

        default:
            return { markdown: `!!Unsupported comment block type: ${block.typename_}!!` }
    }
}

function convertParameterBlock(block: DocCommentEqualListBlock, config: CommentConversionConfig): DocfxBlock {
    const params : DocfxParams = {
        parameters: []
    }

    for(const item of block.items) {
        const param : DocfxParam = {
            name: item.key,
            description: renderParagraphToMarkdown(item.value),
        }

        if(config.lookupParameterType)
            param.type = config.lookupParameterType(item.key)

        params.parameters.push(param)
    }

    return params
}

function renderListToMarkdown(items: DocCommentOrderedListBlockItem[] | DocCommentUnorderedListBlockItem[]): MarkdownString {
    let output = ""
    const rootPrefix = items[0].typename_ === DocCommentOrderedListBlockItem.typename__ ? "1." : "*"
    const nestedPrefix = items[0].typename_ === DocCommentOrderedListBlockItem.typename__ ? "    1.1." : "    *"

    for (let i = 0; i < items.length; i++) {
        const item = items[i]
        const prefix = item.isNested ? rootPrefix : nestedPrefix
        output += `${prefix} ${renderParagraphToMarkdown(item.block)}\n\n`
    }

    return output
}

function renderParagraphToMarkdown(paragraph: DocCommentParagraphBlock): MarkdownString {
    let output = ""

    for(const inline of paragraph.inlines) {
        switch(inline.typename_) {
            case DocCommentTextInline.typename__:
                output += (inline as DocCommentTextInline).text
                break

            case DocCommentBoldInline.typename__:
                output += `**${(inline as DocCommentBoldInline).text}**`
                break

            case DocCommentItalicInline.typename__:
                output += `*${(inline as DocCommentItalicInline).text}*`
                break

            case DocCommentCodeInline.typename__:
                output += `\`${(inline as DocCommentCodeInline).text}\``
                break

            case DocCommentLinkInline.typename__:
                output += `[${(inline as DocCommentLinkInline).text}](${(inline as DocCommentLinkInline).url})`
                break
            
            default:
                output += `!!Unsupported comment inline type: ${inline.typename_}!!`
        }
        output += " "
    }

    return output
}