import { Args, Command, Flags } from '@oclif/core'
import fs from 'fs'
import { DocAggregateType, DocAlias, DocClass, DocFunction, DocModule, DocSoloType, DocStruct, DocVariable } from '../marmos.js'
import { Docfx, DocfxPageType, TypeSet, renderFunctionSignature, generateReferenceTable, marmosCommentGetSummary, marmosCommentToDocfx, organiseTypes, DocfxHeading, DocfxParam, DocfxParams, renderTypeReference, renderAggregateTypeSignature, DocfxPageOptions, DocfxApiPage, ReferenceItem, DocfxFacts, renderSoloTypeSignature } from '../internal/docfx/index.js'

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
  generateTypeSetPages(types, null, docModule.nameComponents, docfx)
  generateOverview(docModule.nameComponents, docfx, docModule, types)
}

function generateTypeSetPages(
  types: TypeSet, 
  parentPage: DocfxPageOptions | null,
  moduleName: string[],
  docfx: Docfx) {
  types.aliases.forEach((alias) => generateGenericSoloType(moduleName, parentPage, docfx, alias, DocfxPageType.alias, "Alias"))
  types.classes.forEach((cls) => generateGenericAggregateType(moduleName, parentPage, docfx, cls, DocfxPageType.class_, "Class"))
  types.enums.forEach((enum_) => generateGenericAggregateType(moduleName, parentPage, docfx, enum_, DocfxPageType.enum_, "Enum"))
  types.functions.forEach((func) => generateFunction(moduleName, parentPage, docfx, types.overloads.get(func.name)!))
  types.interfaces.forEach((interface_) => generateGenericAggregateType(moduleName, parentPage, docfx, interface_, DocfxPageType.interface_, "Interface"))
  types.mixinTemplates.forEach((mixinTemplate) => generateGenericAggregateType(moduleName, parentPage, docfx, mixinTemplate, DocfxPageType.mixinTemplate, "MixinTemplate"))
  types.structs.forEach((struct) => generateGenericAggregateType(moduleName, parentPage, docfx, struct, DocfxPageType.struct, "Struct"))
  types.templates.forEach((template) => generateGenericAggregateType(moduleName, parentPage, docfx, template, DocfxPageType.template, "Template"))
  types.unions.forEach((union) => generateGenericAggregateType(moduleName, parentPage, docfx, union, DocfxPageType.union, "Union"))
  types.variables.forEach((variable) => generateGenericSoloType(moduleName, parentPage, docfx, variable, DocfxPageType.variable, "Variable"))
}

function generateTypeSetReferenceTables(
  types: TypeSet,
  page: DocfxApiPage,
  relativeHrefPrefix: string) {
    maybeAddReferenceTable(page, "Aliases", types.aliases, alias => ({
      name: alias.name,
      description: marmosCommentGetSummary(alias.comment),
      relativeHref: `${relativeHrefPrefix}Aliases/${alias.name}.html`
    }))

    maybeAddReferenceTable(page, "Classes", types.classes, cls => ({
      name: cls.name,
      description: marmosCommentGetSummary(cls.comment),
      relativeHref: `${relativeHrefPrefix}Classes/${cls.name}.html`
    }))

    maybeAddReferenceTable(page, "Enums", types.enums, enum_ => ({
      name: enum_.name,
      description: marmosCommentGetSummary(enum_.comment),
      relativeHref: `${relativeHrefPrefix}Enums/${enum_.name}.html`
    }))

    maybeAddReferenceTable(page, "Functions", types.functions, func => ({
      name: func.name,
      description: marmosCommentGetSummary(func.comment),
      relativeHref: `${relativeHrefPrefix}Functions/${func.name}.html`
    }))

    maybeAddReferenceTable(page, "Interfaces", types.interfaces, interface_ => ({
      name: interface_.name,
      description: marmosCommentGetSummary(interface_.comment),
      relativeHref: `${relativeHrefPrefix}Interfaces/${interface_.name}.html`
    }))

    maybeAddReferenceTable(page, "MixinTemplates", types.mixinTemplates, mixinTemplate => ({
      name: mixinTemplate.name,
      description: marmosCommentGetSummary(mixinTemplate.comment),
      relativeHref: `${relativeHrefPrefix}MixinTemplates/${mixinTemplate.name}.html`
    }))

    maybeAddReferenceTable(page, "Structs", types.structs, struct => ({
      name: struct.name,
      description: marmosCommentGetSummary(struct.comment),
      relativeHref: `${relativeHrefPrefix}Structs/${struct.name}.html`
    }))

    maybeAddReferenceTable(page, "Templates", types.templates, template => ({
      name: template.name,
      description: marmosCommentGetSummary(template.comment),
      relativeHref: `${relativeHrefPrefix}Templates/${template.name}.html`
    }))

    maybeAddReferenceTable(page, "Unions", types.unions, union => ({
      name: union.name,
      description: marmosCommentGetSummary(union.comment),
      relativeHref: `${relativeHrefPrefix}Unions/${union.name}.html`
    }))

    maybeAddReferenceTable(page, "Variables", types.variables, variable => ({
      name: variable.name,
      description: marmosCommentGetSummary(variable.comment),
      relativeHref: `${relativeHrefPrefix}Variables/${variable.name}.html`
    }))
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

function generateGenericSoloType(
  moduleName: string[],
  parentPage: DocfxPageOptions | null,
  docfx: Docfx,
  soloType: DocSoloType,
  pageType: DocfxPageType,
  titlePrefix: string) {

  const facts : DocfxFacts = { facts: [] }
  facts.facts.push({ name: "Module", value: moduleName.join('.') })
  if(parentPage)
    facts.facts.push({ name: "Parent", value: parentPage.pageRawName })

  docfx.newPage({
    moduleName: moduleName,
    parentPage: parentPage,
    pageRawName: soloType.name,
    pageType: pageType
  }, (page) => {
    page.title = `${titlePrefix} - ${soloType.name}`
    page.languageId = "d"

    page.body.push({ h1: page.title })
    page.body.push(facts)
    page.body.push({ api2: soloType.name })
    page.body.push(renderSoloTypeSignature(soloType))
    page.body.push(...marmosCommentToDocfx(soloType.comment, {}))
  })
}

function generateGenericAggregateType(
  moduleName: string[],
  parentPage: DocfxPageOptions | null,
  docfx: Docfx,
  type: DocAggregateType,
  pageType: DocfxPageType,
  titlePrefix: string) {

  const types = organiseTypes(type.nestedTypes, type.members)
  
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

    generateTypeSetReferenceTables(types, page, `../${type.name}/${type.name}/`)
  })
  generateTypeSetPages(types, pageOptions, moduleName.concat(type.name), docfx)
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

      generateTypeSetReferenceTables(types, page, "")
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