/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
import std.getopt : getopt, config, defaultGetoptPrinter;

int main(string[] args)
{
    string testDir;

    auto opt = getopt(
        args,

        config.required,
        "test-dir", "Which directory containing a main.d and expected.json to peform a test in", &testDir,
    );

    if(opt.helpWanted)
    {
        defaultGetoptPrinter("Some information about the program.", opt.options);
        return 0;
    }

    return runTest(testDir) ? 0 : 1;
}

bool runTest(string testDir)
{
    import std.file               : readText, writeText = write;
    import std.path               : buildPath;
    import std.json               : parseJSON;
    import dmd.frontend           : initDMD, parseModule;
    import marmos.generic.visitor : DocVisitor;
    import marmos.output.json     : JsonWriter, toJson;
    
    initDMD();

    const mainFile     = testDir.buildPath("main.d");
    const expectedFile = testDir.buildPath("expected.json");

    auto parseResult = parseModule(mainFile);
    if(parseResult.diagnostics.hasErrors)
        return false;

    auto docMod        = DocVisitor.visitModule(parseResult.module_);
    const expectedText = readText(expectedFile);
    const expectedJson = parseJSON(expectedText);

    JsonWriter json;
    json.reserve();
    docMod.toJson(json);
    const gotJsonText = json.toString;
    const gotJson     = parseJSON(gotJsonText);

    // TODO: Do a proper JSON-aware compare instead of a text comparison
    bool areSame = (gotJsonText == expectedText);
    if(!areSame)
    {
        import std.stdio : writeln;
        writeln("Expected:");
        writeln(expectedText);
        writeln("Got:");
        writeln(gotJsonText);

        writeText(testDir.buildPath("got.json"), gotJsonText);
    }

    return areSame;
}