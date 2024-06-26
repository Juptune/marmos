import { DocAlias, DocFunction, DocVariable, DocClass, DocStruct, DocEnum, DocInterface, DocTemplate, DocMixinTemplate, DocAggregateType, DocSoloType, DocVisibility, DocUnion, DocTypeReference, DocLinkage } from "../../marmos.js";
import { marmosCommentGetSummary } from "./comments.js";
import { DocfxBlock, DocfxCode, MarkdownString } from "./model.js";

export type ReferenceItem = {
  name: string,
  relativeHref: string,
  description: string,
}

export type RenderFunctionOptions = {
  multiLine: boolean
}

export function generateReferenceTable(items: ReferenceItem[]): DocfxBlock {
  items.sort((a, b) => a.name.localeCompare(b.name))

  let output = "Name | Description\n-- | --\n"
  for (const item of items) {
    output += `[${item.name}](${item.relativeHref}) | ${item.description.replaceAll('|', '`|`')}\n`
  }

  return { markdown: output }
}

export function renderFunctionSignature(func: DocFunction, options: RenderFunctionOptions): DocfxCode {
  const newLine = options.multiLine ? "\n" : " "
  const indent = options.multiLine ? "  " : ""

  let output = ""
  if (func.visibility !== DocVisibility.undefined)
    output += `${func.visibility} `

  if (func.linkage !== DocLinkage.d)
    output += `${func.linkage} `

  output += `${renderTypeReference(func.returnType)} ${func.name}(${newLine}`
  func.parameters.forEach(p => {
    output += `${indent}${renderTypeReference(p.type)} ${p.name}`
    if(p !== func.parameters[func.parameters.length - 1])
      output += `,${newLine}`
    else
      output += newLine
  })
  output += `) ${func.storageClasses.join(' ')}`

  return { code: output }
}

export function renderAggregateTypeSignature(type: DocAggregateType): DocfxCode {
  let keyword = ""
  let storageClasses = type.storageClasses
  let linkage = type.linkage
  let visibility = type.visibility
  let members = type.members
  let nestedTypes = type.nestedTypes

  switch (type.typename_) {
    case DocClass.typename__:
      keyword = "class"
      break

    case DocStruct.typename__:
      keyword = "struct"
      break

    case DocEnum.typename__:
      keyword = "enum"
      break

    case DocInterface.typename__:
      keyword = "interface"
      break

    case DocTemplate.typename__:
      keyword = "template"
      break

    case DocMixinTemplate.typename__:
      keyword = "mixin template"
      break

    case DocUnion.typename__:
      keyword = "union"
      break

    default:
      keyword = "<bug: cannot determine keyword>"
      break
  }

  let output = ""
  if (visibility !== DocVisibility.undefined)
    output += `${visibility} `
  if (linkage !== DocLinkage.d)
    output += `${linkage} `
  if (storageClasses.length > 0)
    output += `${storageClasses.join(' ')} `
  output += `${keyword} ${type.name}` // TODO: Template parameters whenever the marmos model supports them
  output += "\n{"

  // Order members by type then name
  if (members.length > 0) {
    const membersCopy = members.slice().sort((a, b) => {
      if (a.typename_ !== b.typename_)
        return a.typename_.localeCompare(b.typename_)
      return a.name.localeCompare(b.name)
    })

    let lastTypeName = membersCopy[0].typename_
    
    onlyPublicMembers(membersCopy).forEach(m => {
      if (lastTypeName !== m.typename_)
        output += "\n"
      lastTypeName = m.typename_
      output += `\n  // ${marmosCommentGetSummary(m.comment)}`
      output += `\n  ${renderSoloTypeSignature(m).code};`
    })
  }

  output += "\n}"
  return { code: output }
}

export function renderSoloTypeSignature(type: DocSoloType): DocfxCode {
  let output = ""
  if (type.visibility !== DocVisibility.undefined)
    output += `${type.visibility} `
  if (type.linkage !== DocLinkage.d)
    output += `${type.linkage} `
  if (type.storageClasses.length > 0)
    output += `${type.storageClasses.join(' ')} `

  switch (type.typename_) {
    case DocAlias.typename__:
      output += `alias ${type.name} = <todo: marmos support pending>`
      break

    case DocVariable.typename__:
      output += `${renderTypeReference((type as DocVariable).type)} ${type.name}`
      break

    case DocFunction.typename__:
      return renderFunctionSignature(type as DocFunction, { multiLine: false })

    default:
      output += `<bug: unknown>`
      break
  }

  return { code: output }
}

export function renderTypeReference(type: DocTypeReference): string {
  return type.nameComponents.length == 0 ? "<bug: unknown>" : type.nameComponents.join('')
}

export function onlyPublicMembers(members: DocSoloType[]): DocSoloType[] {
  return members.filter(m => 
    (m.visibility === DocVisibility.public_ || m.visibility === DocVisibility.undefined)
    && !m.name.startsWith('_')
  )
}

export type TypeSet = {
  aliases: DocAlias[],
  functions: DocFunction[],
  variables: DocVariable[],
  overloads: Map<string, DocFunction[]>,

  classes: DocClass[],
  structs: DocStruct[],
  enums: DocEnum[],
  interfaces: DocInterface[],
  templates: DocTemplate[],
  mixinTemplates: DocMixinTemplate[],
  unions: DocAggregateType[],

  others: (DocAggregateType | DocSoloType)[],
}

export function organiseTypes(types: DocAggregateType[], soloTypes: DocSoloType[]): TypeSet {
  const typeSet: TypeSet = {
    aliases: [],
    functions: [],
    variables: [],
    overloads: new Map(),
    classes: [],
    structs: [],
    enums: [],
    interfaces: [],
    templates: [],
    mixinTemplates: [],
    unions: [],
    others: [],
  }

  // Collapse eponymous templates
  for (let i = 0; i < types.length; i++) {
    const type = types[i]
    if (type.typename_ !== DocTemplate.typename__)
      continue

    const template = type as DocTemplate
    if (!template.isEponymous)
      continue

    template.nestedTypes.forEach(t => t.comment = template.comment)
    template.members.forEach(t => t.comment = template.comment)

    types.push(...template.nestedTypes)
    soloTypes.push(...template.members)
    types.splice(i, 1)
    i--
  }

  soloTypes.forEach((type) => {
    switch (type.typename_) {
      case DocAlias.typename__:
        const alias = type as DocAlias
        if (alias.visibility === DocVisibility.private_)
          break

        typeSet.aliases.push(alias)
        break

      case DocFunction.typename__:
        const func = type as DocFunction
        if (func.name.startsWith('_') || func.visibility === DocVisibility.private_)
          break

        const overloads = typeSet.overloads.get(func.name)
        if (!overloads) {
          typeSet.overloads.set(func.name, [func])
          typeSet.functions.push(func as DocFunction)
        }
        else
          overloads.push(func)
        break

      case DocVariable.typename__:
        const variable = type as DocVariable
        if (variable.name.startsWith('_') || variable.visibility === DocVisibility.private_)
          break

        typeSet.variables.push(variable)
        break

      default:
        typeSet.others.push(type)
        break
    }
  })

  types.forEach((type) => {
    switch (type.typename_) {
      case DocClass.typename__:
        const class_ = type as DocClass
        if (class_.name.startsWith('_') || class_.visibility === DocVisibility.private_)
          break
        typeSet.classes.push(class_)
        break
      case DocStruct.typename__:
        const struct = type as DocStruct
        if (struct.name.startsWith('_') || struct.visibility === DocVisibility.private_)
          break
        typeSet.structs.push(struct)
        break
      case DocEnum.typename__:
        const enum_ = type as DocEnum
        if (enum_.name.startsWith('_') || enum_.visibility === DocVisibility.private_)
          break
        typeSet.enums.push(enum_)
        break
      case DocInterface.typename__:
        const interface_ = type as DocInterface
        if (interface_.name.startsWith('_') || interface_.visibility === DocVisibility.private_)
          break
        typeSet.interfaces.push(interface_)
        break
      case DocTemplate.typename__:
        const template = type as DocTemplate
        if (template.name.startsWith('_') || template.visibility === DocVisibility.private_)
          break
        typeSet.templates.push(template)
        break
      case DocMixinTemplate.typename__:
        const mixinTemplate = type as DocMixinTemplate
        if (mixinTemplate.name.startsWith('_') || mixinTemplate.visibility === DocVisibility.private_)
          break
        typeSet.mixinTemplates.push(mixinTemplate)
        break
      case DocUnion.typename__:
        const union = type as DocUnion
        if (union.name.startsWith('_') || union.visibility === DocVisibility.private_)
          break
        typeSet.unions.push(union)
        break
      default:
        typeSet.others.push(type)
        break
    }
  })

  return typeSet
}