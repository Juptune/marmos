export type DocfxTableOfContentNode = {
  name?: string
  href?: string
  items?: Array<DocfxTableOfContentNode>
  uid?: string
  expanded?: boolean
  order?: number
}

// Fortunately Docfx have seemingly defined their schemas in Typescript: https://dotnet.github.io/docfx/docs/api-page.html

export type MarkdownString = string

export type DocfxApiPage = {
  title: string
  metadata?: {[key: string]: string | string[]}
  languageId?: string
  body: DocfxBlock[]
}

export type DocfxInline = DocfxSpan | DocfxSpan[]
export type DocfxBlock =
  | DocfxHeading
  | DocfxMarkdown
  | DocfxCode
  | DocfxApi
  | DocfxFacts
  | DocfxList
  | DocfxInheritance
  | DocfxParams

export type DocfxSpan = string | {text: string; url?: string}

export type DocfxMarkdown = {
  markdown: MarkdownString
}

export type DocfxCode = {
  code: string
  languageId?: string
}

export type DocfxHeading =
  | {h1: string; id?: string}
  | {h2: string; id?: string}
  | {h3: string; id?: string}
  | {h4: string; id?: string}
  | {h5: string; id?: string}
  | {h6: string; id?: string}

export type DocfxApi = ({api1: string} | {api2: string} | {api3: string} | {api4: string}) & {
  id?: string
  deprecated?: boolean | string
  preview?: boolean | string
  src?: string
  metadata?: {[key: string]: string}
}

export type DocfxFacts = {
  facts: {
    name: string
    value: DocfxInline
  }[]
}

export type DocfxList = {
  list: DocfxInline[]
}

export type DocfxInheritance = {
  inheritance: DocfxInline[]
}

export type DocfxParam = {
  name?: string
  type?: DocfxInline
  default?: string
  description?: MarkdownString
  deprecated?: boolean | string
  preview?: boolean | string
}

export type DocfxParams = {
  parameters: DocfxParam[]
}
