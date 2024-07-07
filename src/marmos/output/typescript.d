/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.output.typescript;

// This module is kind of hacky and not very robust, but it's good enough for now.
// My concern was to get something working quickly, so I didn't spend much time on a
// more maintainable solution. I'll probably rewrite this module in the future.

import std.array   : Appender;
import std.sumtype : SumType;
import std.traits  : isNumeric, isDynamicArray, isInstanceOf, fullyQualifiedName, TemplateArgsOf;
import marmos.generic.model;

void generateAllTypeScriptDefinitions(scope ref Appender!(char[]) code)
{
    import std.algorithm : startsWith;

    static foreach(Member; __traits(allMembers, marmos.generic.model))
    static if(Member.startsWith("Doc"))
    {{
        alias Symbol = __traits(getMember, marmos.generic.model, Member);
        static if(!__traits(isTemplate, Symbol))
            generateTypeScriptDefinition!Symbol(code);
    }}

    // TODO: Support enums that use their names rather than values.
    code.put("export enum Edition { none, legacy, v2024 }\n");
    code.put("export function validateEnumEdition(_obj: any): asserts _obj is Edition { }\n");

    code.put(`
        /// Returns the user data of a node, creating it if it doesn't exist.
        ///
        /// The user data is a field that can be used to store arbitrary data on a node,
        /// it is not used by this library or marmos itself.
        export function getUserData<UserDataT>(
            node: { userdata_: any } ,
            def: UserDataT | {} = {}
        ): UserDataT
        {
            if(!node.userdata_)
                node.userdata_ = def;
            return node.userdata_ as UserDataT;
        }
    `);
}

void generateTypeScriptDefinition(T)(scope ref Appender!(char[]) code)
if(is(T == struct) && !isInstanceOf!(SumType, T))
{
    import std.algorithm : substitute, splitter;
    import std.string    : lineSplitter;

    scope Appender!(char[]) fields;
    scope Appender!(char[]) validateBody;

    fields.put("static typename__ = '");
    fields.put(fullyQualifiedName!T);
    fields.put("';\n");

    fields.put("typename_ : '");
    fields.put(fullyQualifiedName!T);
    fields.put("' = '");
    fields.put(fullyQualifiedName!T);
    fields.put("' \n");

    fields.put("userdata_ : any = null\n");

    validateBody.put("if(!obj || typeof obj !== 'object') throw Error('obj is not an object');\n");
    validateBody.put("obj.typename_ = obj.typename_ || obj[\"@type\"];\n");
    validateBody.put("if(obj.typename_ !== '");
    validateBody.put(fullyQualifiedName!T);
    validateBody.put("') throw Error(`typename '${obj.typename_}' is not valid for type ");
    validateBody.put(fullyQualifiedName!T);
    validateBody.put("`);\n");

    static foreach(i, Member; __traits(allMembers, T))
    {{
        alias Symbol = __traits(getMember, T, Member);
        enum isFunction = __traits(compiles, __traits(getFunctionAttributes, Symbol));
        enum isNestedStruct = Member == "Item"; // idk how to detect this properly

        static if(isNestedStruct)
            generateTypeScriptDefinition!Symbol(code);
        else static if(!isFunction)
            addField!(typeof(Symbol), Member)(fields, validateBody);
    }}

    const TypeName = FieldNameOf!T;

    auto fieldDataNoTypename = fields.data;
    int newLineCount = 0;
    foreach(i, ch; fieldDataNoTypename)
    {
        if(ch == '\n')
            newLineCount++;
        if(newLineCount == 2)
        {
            fieldDataNoTypename = fieldDataNoTypename[i+1..$];
            break;
        }
    }

    code.put("export class ");
    code.put(TypeName);
    code.put("\n{\n");
    
    code.put(fields.data);

    code.put("\nconstructor(");
    code.put(fieldDataNoTypename.substitute!('\n', ','));
    code.put(")\n{\n");
    foreach(line; fieldDataNoTypename.splitter('\n'))
    {
        auto nameRange = line.splitter(':');
        if(nameRange.empty)
            continue;
        code.put("this.");
        code.put(nameRange.front);
        code.put(" = ");
        code.put(nameRange.front);
        code.put(";\n");
    }
    code.put("}\n\n");

    code.put("\nstatic validate(obj: any): asserts obj is ");
    code.put(TypeName);
    code.put("\n{\n");
    code.put(validateBody.data);
    code.put("\n}\n");

    code.put("}\n\n");
}

void generateTypeScriptDefinition(T)(scope ref Appender!(char[]) code)
if(is(T == struct) && isInstanceOf!(SumType, T))
{
    code.put("// NOTE: Only typename_ is intended to be a common field for all types, do not rely on other fields\n");
    code.put("//       to be present in all types in the future.\n");
    code.put("export type ");
    code.put(FieldNameOf!T);
    code.put(" = ");
    static foreach(i, Arg; TemplateArgsOf!T)
    {{
        static if(i > 0)
            code.put(" | ");
        code.put(FieldNameOf!Arg);
    }}
    code.put("\n\n");

    code.put("export function validateSumType");
    code.put(FieldNameOf!T);
    code.put("(obj: any): asserts obj is ");
    code.put(FieldNameOf!T);
    code.put("\n{\n");
    code.put("obj.typename_ = obj.typename_ || obj[\"@type\"];\n");
    code.put("const typename = obj.typename_;\n");
    code.put("if(!typename) throw Error('obj does not provide a typename_');\n");
    static foreach(i, Arg; TemplateArgsOf!T)
    {{
        code.put("if(typename === ");
        code.put(FieldNameOf!Arg);
        code.put(".typename__) { ");
        code.put(FieldNameOf!Arg);
        code.put(".validate(obj); return; }\n");
    }}
    code.put("throw Error(`typename '${typename}' is not valid for Sum Type ");
    code.put(FieldNameOf!T);
    code.put("`);\n}\n\n");
}

void generateTypeScriptDefinition(T)(scope ref Appender!(char[]) code)
if(is(T == enum))
{
    code.put("// NOTE: Enum names may change in the future\n");
    code.put("export enum ");
    code.put(T.stringof);
    code.put("\n{\n");
    static foreach(i, Member; __traits(allMembers, T))
    {{
        alias Symbol = __traits(getMember, T, Member);
        code.put(Member);
        code.put(" = '");
        code.put(cast(string)Symbol);
        code.put("',\n");
    }}
    code.put("}\n\n");

    code.put("export function validateEnum");
    code.put(T.stringof);
    code.put("(obj: any): asserts obj is ");
    code.put(T.stringof);
    code.put("\n{\n");
    code.put("if(typeof obj !== 'string' || !Object.values(");
    code.put(T.stringof);
    code.put(").includes(obj as any)) throw Error(`value ${obj} is either not a string, or not valid for Enum ");
    code.put(T.stringof);
    code.put("`);\n}\n\n");
}

// unittest
// {
//     import std.file : write;
//     Appender!(char[]) code;
//     generateAllTypeScriptDefinitions(code);
//     write("test.ts", code.data);
//     assert(false);
// }

private:

void addField(Type, string Name)(scope ref Appender!(char[]) fields, scope ref Appender!(char[]) validate)
if(isNumeric!Type && !is(Type == enum))
{
    fields.put(Name);
    fields.put(" : number\n");

    addFieldTypeOfValidator(validate, Name, "number");
}

void addField(Type, string Name)(scope ref Appender!(char[]) fields, scope ref Appender!(char[]) validate)
if(is(Type == string) && !is(Type == enum))
{
    fields.put(Name);
    fields.put(" : string\n");

    addFieldTypeOfValidator(validate, Name, "string");
}

void addField(Type, string Name)(scope ref Appender!(char[]) fields, scope ref Appender!(char[]) validate)
if(is(Type == bool))
{
    fields.put(Name);
    fields.put(" : boolean\n");

    addFieldTypeOfValidator(validate, Name, "boolean");
}

void addField(Type, string Name)(scope ref Appender!(char[]) fields, scope ref Appender!(char[]) validate)
if(is(Type == enum))
{
    fields.put(Name);
    fields.put(" : ");
    fields.put(FieldNameOf!Type);
    fields.put("\n");

    validate.put("validateEnum");
    validate.put(Type.stringof);
    validate.put("(obj.");
    validate.put(Name);
    validate.put(");\n");
}

void addField(Type, string Name)(scope ref Appender!(char[]) fields, scope ref Appender!(char[]) validate)
if(isDynamicArray!Type && !is(Type == string) && !is(Type == enum))
{
    static if(is(Type : Element[], Element))
    {
        immutable ElementName = FieldNameOf!Element;

        fields.put(Name);
        fields.put(" : ");
        fields.put("Array<");
        fields.put(ElementName);
        fields.put(">\n");

        addFieldValidator(validate, Name, delegate(scope ref expression) {
            expression.put("!Array.isArray(obj.");
            expression.put(Name);
            expression.put(")");
        });

        validate.put("for(const item of obj.");
        validate.put(Name);
        validate.put(")\n{\n");
        static if(is(Element == struct))
        {
            static if(isInstanceOf!(SumType, Element))
            {
                validate.put("validateSumType");
                validate.put(ElementName);
                validate.put("(item);\n");
            }
            else
            {
                validate.put(ElementName);
                validate.put(".validate(item);\n");
            }
        }
        else static if(is(Element == enum))
        {
            validate.put("validateEnum");
            validate.put(ElementName);
            validate.put("(item);\n");
        }
        else
        {
            validate.put("// TODO: Add array validation for non-struct type ");
            validate.put(ElementName);
            validate.put("\n");
        }
        validate.put("}\n");
    }
}

void addField(Type, string Name)(scope ref Appender!(char[]) fields, scope ref Appender!(char[]) validate)
if(is(Type == struct))
{
    fields.put(Name);
    fields.put(" : ");
    fields.put(FieldNameOf!Type);
    fields.put("\n");

    validate.put(FieldNameOf!Type);
    validate.put(".validate(obj.");
    validate.put(Name);
    validate.put(");\n");
}

void addFieldTypeOfValidator(
    scope ref Appender!(char[]) validate,
    string fieldInObj,
    string typeName,
    string objVarName = "obj",
)
{
    addFieldValidator(validate, fieldInObj, delegate(scope ref expression) {
        expression.put("typeof ");
        expression.put(objVarName);
        expression.put(".");
        expression.put(fieldInObj);
        expression.put(" !== '");
        expression.put(typeName);
        expression.put("'");
    }, objVarName);
}

void addFieldValidator(
    scope ref Appender!(char[]) validate,
    string fieldInObj,
    void delegate(scope ref Appender!(char[])) additionalValidation = null,
    string objVarName = "obj",
)
{
    validate.put("if(");
    validate.put(objVarName);
    validate.put(".");
    validate.put(fieldInObj);
    validate.put(" === undefined");
    if(additionalValidation)
    {
        validate.put(" || (");
        additionalValidation(validate);
        validate.put(")"); 
    }
    validate.put(") throw Error('field ");
    validate.put(fieldInObj);
    validate.put(" is missing or not of the correct type');\n");
}

template FieldNameOf(T)
{
    static if(isInstanceOf!(SumType, T))
    {
        static if(is(T == DocCommentBlock))
            immutable FieldNameOf = "DocCommentBlock";
        else static if(is(T == DocCommentInline))
            immutable FieldNameOf = "DocCommentInline";
        else static if(is(T == DocAggregateType))
            immutable FieldNameOf = "DocAggregateType";
        else static if(is(T == DocSoloType))
            immutable FieldNameOf = "DocSoloType";
        else
            static assert(false, "Need to manually specify FieldNameOf for SumType " ~ T.stringof);
    }
    else static if(__traits(compiles, __traits(identifier, T)))
    {
        static if(__traits(identifier, T) == "Item") // TODO: Better way to detect nested struct
            immutable FieldNameOf = __traits(identifier, __traits(parent, T)) ~ "Item";
        else
            immutable FieldNameOf = __traits(identifier, T);
    }
    else
        immutable FieldNameOf = T.stringof;
}