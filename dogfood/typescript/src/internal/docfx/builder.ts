import fs from 'fs';
import { DocfxApi, DocfxApiPage, DocfxTableOfContentNode } from './model.js';
import yaml from 'yaml';
import path from 'path';

export type DocfxOptions = {
    outputFolder: fs.PathLike;
}

export type DocfxPageOptions = {
    moduleName: string[],
    parentPage: DocfxPageOptions | null,
    pageType: DocfxPageType,
    pageRawName: string,
    _uidComponents?: string[],
    _uidDotted?: string,
    _uidAsFilePath?: string,
    _tocDirName?: string,
}

export enum DocfxPageType {
    alias = "Aliases",
    class_ = "Classes",
    enum_ = "Enums",
    struct = "Structs",
    function = "Functions",
    interface_ = "Interfaces",
    template = "Templates",
    mixinTemplate = "Templates (Mixin)",
    union = "Unions",
    other = "Other Members",
    variable = "Variables",
    overview = "Overview",
}

type FinishedPage = {
    options: DocfxPageOptions,
    page: DocfxApiPage,
    filePath: string,
}

type VirtualToc = {
    pages: FinishedPage[]
    filePath: string
    pathRelativeToParentToc: string
    childTocs: Map<string, VirtualToc>
}

export class Docfx {
    constructor(
        private options: DocfxOptions,
        private tocsByDirName: Map<string, VirtualToc> = new Map(),
    ) {
        this.options = options;
        this.tocsByDirName = tocsByDirName;

        if (!fs.existsSync(options.outputFolder)) {
            throw Error(`Output folder does not exist: ${options.outputFolder}. marmos-docfx will create subfolders as needed, but the root folder must exist.`);
        }
    }

    public newPage(
        pageOptions: DocfxPageOptions, 
        populate: (page: DocfxApiPage) => void
    ) {
        const toc = this.tocForPage(pageOptions)
        const page : DocfxApiPage = {
            body: [],
            title: "",
            metadata: {
                uid: pageOptions._uidDotted!,
            },
        }
        populate(page)

        toc.pages.push({
            options: pageOptions,
            page: page,
            filePath: path.join(
                this.options.outputFolder.toString(), 
                pageOptions._uidAsFilePath + ".yml"
            ),
        })
    }

    public finish() {
        for(const [dirName, toc] of this.tocsByDirName) {
            const tocNode: DocfxTableOfContentNode = {
                items: [],
            }

            for(const page of toc.pages) {
                tocNode.items!.push({
                    name: page.options.pageRawName,
                    href: page.options._uidComponents![page.options._uidComponents!.length - 1] + ".yml",
                })
            }

            for(const [name, childToc] of toc.childTocs) {
                tocNode.items!.push({
                    name: name,
                    href: childToc.pathRelativeToParentToc,
                })
            }

            fs.mkdirSync(path.dirname(toc.filePath), {recursive: true})
            fs.writeFileSync(toc.filePath, yaml.stringify(tocNode))
            for(const page of toc.pages) {
                fs.mkdirSync(path.dirname(page.filePath), {recursive: true})
                fs.writeFileSync(page.filePath, "#YamlMime:ApiPage\n"+yaml.stringify(page.page))
            }
        }
    }

    private tocForPage(page: DocfxPageOptions): VirtualToc {
        ensureUids(page)
        let toc = this.tocsByDirName.get(page._tocDirName!)
        if(toc)
            return toc
        
        let dirName = ""
        for(let i = 0; i < page._uidComponents!.length-1; i++) {
            const parentDirName = dirName
            if(dirName.length > 0) {
                dirName += "/"
            }
            dirName += page._uidComponents![i]

            toc = this.tocsByDirName.get(dirName)
            if(toc)
                continue

            toc = {
                filePath: path.join(
                    this.options.outputFolder.toString(), 
                    dirName + "/toc.yml"
                ),
                pages: [],
                childTocs: new Map(),
                pathRelativeToParentToc: page._uidComponents![i] + "/toc.yml",
            }
            this.tocsByDirName.set(dirName, toc)

            if(!page.parentPage) // Don't add subpages to TOC... for now at least
            {
                const parentToc = this.tocsByDirName.get(parentDirName)
                if(parentToc)
                    parentToc.childTocs.set(page._uidComponents![i], toc)
            }
        }

        if(!toc)
            throw Error("bug: toc not found for page, and it wasn't created.")
        return toc
    }
}

export function ensureUids(page: DocfxPageOptions) {
    if(!page._uidComponents) {
        page._uidComponents = [...page.moduleName]
        if(page.parentPage)
            page._uidComponents.push(page.parentPage.pageRawName)
        if (page.pageType !== DocfxPageType.overview)
            page._uidComponents.push(page.pageType)
        page._uidComponents.push(page.pageRawName)
        page._uidDotted = page._uidComponents.join('.')
        page._uidAsFilePath = page._uidComponents.join('/')
        
        page._tocDirName = ""
        for(let i = 0; i < page._uidComponents.length-1; i++) {
            if(i > 0) {
                page._tocDirName += "/"
            }
            page._tocDirName += page._uidComponents[i]
        }
    }
}