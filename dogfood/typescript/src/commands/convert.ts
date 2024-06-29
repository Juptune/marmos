import { Args, Command, Flags } from '@oclif/core'
import fs from 'fs'
import { DocClass, DocFunction, DocModule, DocStruct } from '../marmos.js'
import { Docfx, DocfxPageType, TypeSet, renderFunctionSignature, generateReferenceTable, marmosCommentGetSummary, marmosCommentToDocfx, organiseTypes, DocfxHeading, DocfxParam, DocfxParams, renderTypeReference, renderAggregateTypeSignature, DocfxPageOptions, DocfxApiPage, ReferenceItem, DocfxFacts } from '../internal/docfx/index.js'

export default class Convert extends Command {
  static strict = false
  static override args = {
    inputFiles: Args.string({ description: '.json files containing a marmos model to convert' }),
  }

  static override flags = {
    outputFolder: Flags.directory({ description: 'output folder for the docfx model', required: true })
  }

  static override description = 'describe the command here'

  static override examples = [
    '<%= config.bin %> <%= command.id %>',
  ]

  public async run(): Promise<void> {
    const { argv, flags } = await this.parse(Convert)
    const docfx = new Docfx({
      outputFolder: flags.outputFolder,
    })

    argv.forEach((inputFile: unknown) => convertToDocfxModel(inputFile as string, docfx))
    docfx.finish()
  }
}

function convertToDocfxModel(inputFile: string, docfx: Docfx) {
  console.log(`Converting ${inputFile} to Docfx model`)
  const rawJson = fs.readFileSync(inputFile, 'utf8')
  const docModule = JSON.parse(rawJson)
  DocModule.validate(docModule)

  const types = organiseTypes(docModule.types, docModule.soloTypes)
  types.classes.forEach((cls) => generateClassOrStruct(docModule.nameComponents, null, docfx, cls))
  types.structs.forEach((struct) => generateClassOrStruct(docModule.nameComponents, null, docfx, struct))
  types.functions.forEach((func) => generateFunction(docModule.nameComponents, null, docfx, types.overloads.get(func.name)!))
  generateOverview(docModule.nameComponents, docfx, docModule, types)
}

function generateFunction(
  moduleName: string[],
  parentPage: DocfxPageOptions | null,
  docfx: Docfx,
  overloads: DocFunction[]) {

  const name = overloads[0].name

  const facts : DocfxFacts = { facts: [] }
  facts.facts.push({ name: "Module", value: moduleName.join('.') })
  if(parentPage)
    facts.facts.push({ name: "Parent", value: parentPage.pageRawName })

  docfx.newPage({
    moduleName: moduleName,
    parentPage: parentPage,
    pageRawName: name,
    pageType: DocfxPageType.function
  }, (page) => {
    page.title = `Overloads for - ${name}`
    page.languageId = "d"

    page.body.push({ h1: page.title })
    page.body.push(facts)

    for(const overload of overloads) {
      const lookupType = (name: string) => {
        const param = overload.parameters.find(p => p.name === name)
        return param ? renderTypeReference(param.type) : "<parameter not found>"
      }
      const nameWithBareParams = `${overload.name}(${overload.parameters.map(p => p.name).join(', ')})`
      const commentBlocks = marmosCommentToDocfx(overload.comment, {
        createAboutHeader: false,
        lookupParameterType: lookupType,
      })

      page.body.push({ api2: nameWithBareParams })
      page.body.push(renderFunctionSignature(overload, { multiLine: true }))
      page.body.push(...commentBlocks)
    }
  })
}

function generateClassOrStruct(
  moduleName: string[],
  parentPage: DocfxPageOptions | null,
  docfx: Docfx,
  type: DocClass | DocStruct) {

  const isClass = type.typename_ === DocClass.typename__
  const pageType = isClass ? DocfxPageType.class_ : DocfxPageType.struct
  const titlePrefix = isClass ? "Class" : "Struct"
  const types = organiseTypes([], type.members)
  
  const facts : DocfxFacts = { facts: [] }
  facts.facts.push({ name: "Module", value: moduleName.join('.') })
  if(parentPage)
    facts.facts.push({ name: "Parent", value: parentPage.pageRawName })

  const pageOptions = {
    moduleName: moduleName,
    parentPage: parentPage,
    pageRawName: type.name,
    pageType: pageType
  }

  docfx.newPage(pageOptions, (page) => {
    page.title = `${titlePrefix} - ${type.name}`
    page.languageId = "d"

    page.body.push({ h1: page.title })
    page.body.push(facts)
    page.body.push(renderAggregateTypeSignature(type))
    page.body.push(...marmosCommentToDocfx(type.comment, {}))

    maybeAddReferenceTable(page, "Aliases", types.aliases, alias => ({
      name: alias.name,
      description: marmosCommentGetSummary(alias.comment),
      relativeHref: `../${type.name}/Aliases/${alias.name}.html`
    }))

    maybeAddReferenceTable(page, "Functions", types.functions, func => ({
      name: func.name,
      description: marmosCommentGetSummary(func.comment),
      relativeHref: `../${type.name}/Functions/${func.name}.html`
    }))

    maybeAddReferenceTable(page, "Variables", types.variables, variable => ({
      name: variable.name,
      description: marmosCommentGetSummary(variable.comment),
      relativeHref: `../${type.name}/Variables/${variable.name}.html`
    }))
  })

  types.functions.forEach(func => generateFunction(moduleName, pageOptions, docfx, types.overloads.get(func.name)!))
}

function generateOverview(
  moduleName: string[],
  docfx: Docfx,
  docModule: DocModule,
  types: TypeSet) {

    docfx.newPage({
      moduleName: moduleName,
      parentPage: null,
      pageRawName: "Overview",
      pageType: DocfxPageType.overview
    }, (page) => {
      page.title = `Module - ${moduleName.join('.')}`
      page.languageId = "d"

      page.body.push({ h1: page.title })
      page.body.push(...marmosCommentToDocfx(docModule.comment, {}))

      maybeAddReferenceTable(page, "Aliases", types.aliases, alias => ({
        name: alias.name,
        description: marmosCommentGetSummary(alias.comment),
        relativeHref: `Aliases/${alias.name}.html`
      }))

      maybeAddReferenceTable(page, "Classes", types.classes, cls => ({
        name: cls.name,
        description: marmosCommentGetSummary(cls.comment),
        relativeHref: `Classes/${cls.name}.html`
      }))

      maybeAddReferenceTable(page, "Structs", types.structs, struct => ({
        name: struct.name,
        description: marmosCommentGetSummary(struct.comment),
        relativeHref: `Structs/${struct.name}.html`
      }))

      maybeAddReferenceTable(page, "Functions", types.functions, func => ({
        name: func.name,
        description: marmosCommentGetSummary(func.comment),
        relativeHref: `Functions/${func.name}.html`
      }))

      maybeAddReferenceTable(page, "Variables", types.variables, variable => ({
        name: variable.name,
        description: marmosCommentGetSummary(variable.comment),
        relativeHref: `Variables/${variable.name}.html`
      }))
    })
}

function maybeAddReferenceTable<DocT>(
  page: DocfxApiPage, 
  title: string, 
  items: DocT[],
  map: (item: DocT) => ReferenceItem) {

    if(items.length === 0)
        return
    page.body.push({ h2: title })
    page.body.push(generateReferenceTable(items.map(item => map(item))))
}