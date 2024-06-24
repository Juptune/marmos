/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.main;

import std.getopt : getopt, config, defaultGetoptPrinter;
import marmos.generic.model, marmos.generic.visitor;

shared static this()
{
    import dmd.frontend : initDMD;
    initDMD();
}

int main(string[] args)
{
    // TODO: Integrate a proper CLI library

    void showHelp()
    {
        import std.stdio : writeln;
        writeln("Usage: marmos <command> [options]");
        writeln("Commands:");
        writeln("  generate-generic - Generate a generic model from a D module.");
        writeln("  generate-typescript - Generate TypeScript definitions for the Marmos model.");
    }

    if(args.length == 1)
    {
        showHelp();
        return 1;
    }

    import std.algorithm : remove;
    switch(args[1])
    {
        case "generate-typescript":
            return commandGenerateTypeScript(args.remove(1));

        case "generate-generic":
            return commandGenerateGeneric(args.remove(1));

        default:
            showHelp();
            return 1;
    }
}

private:

int commandGenerateTypeScript(string[] args)
{
    import std.array   : Appender;
    import std.file    : write;
    import std.process : spawnProcess, wait;
    import marmos.output.typescript : generateAllTypeScriptDefinitions;

    const fileName = "marmos.ts";
    bool format = false;

    auto opt = getopt(
        args,

        "format", "Format the output using Prettier, must have npm installed.", &format
    );

    if(opt.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.", opt.options);
        return 0;
    }

    Appender!(char[]) code;
    code.reserve(1024 * 1024);
    code.put(
`/*
    Auto-generated using: marmos generate-typescript

    This file contains TypeScript definitions for the Marmos generic model.

    Any changes made to this file will be overwritten the next time the command is run.

    This file is generated under Public Domain, so feel free to use it in any way you like.

    Steps to use this file:
        - Read in a JSON file containing the marmos generic model.
        - Call DocModule.validate(jsonObject) to validate the JSON object, catching any errors.
        - TypeScript will now also be able to infer the types of the object.
*/
`);
    generateAllTypeScriptDefinitions(code);
    write(fileName, code.data);

    if(format)
    {
        auto pid = spawnProcess(["npx", "--yes", "prettier", "--write", fileName, "--ignore-path="]);
        return wait(pid);
    }

    return 0;
}

int commandGenerateGeneric(string[] args)
{
    import std.array            : join;
    import std.file             : write;
    import std.stdio            : writeln;
    import marmos.output.json   : JsonWriter, toJson;

    auto fileName = "";

    auto opt = getopt(
        args,

        "output-file", "The name of the output JSON file. Defaults to the parsed module name.", &fileName
    );

    if(opt.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.", opt.options);
        return 0;
    }

    if(args.length == 1)
    {
        import std.stdio : writeln;
        writeln("Error: No input file specified.");
        return 1;
    }

    auto mod = parseFile(args[1]);
    auto json = JsonWriter();
    json.reserve();
    mod.toJson(json);

    if(fileName == "")
        fileName = (mod.nameComponents.length > 0 ? mod.nameComponents.join(".") : "__anonymous") ~ ".json";
    
    if(fileName == "-")
        writeln(json.toString());
    else
        write(fileName, json.toString());

    return 0;
}

DocModule parseFile(const string filename)
{
    import dmd.frontend     : parseModule;
    import std.exception    : enforce;
    import std.file         : readText;

    const code = readText(filename);
    auto result = parseModule("unittest", code);
    enforce(!result.diagnostics.hasErrors, "Errors occurred during parsing");

    return DocVisitor.visitModule(result.module_);
}