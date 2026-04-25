/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.test.runner;

import std.exception    : enforce;
import std.logger       : infof, errorf, tracef;
import std.sumtype      : SumType, match;
import std.json         : JSONValue, JSONType;

import argparse : CLI;

alias TestType = SumType!(SingleFileDriftTest);

struct Config
{
    TestType test;
}

struct SingleFileDriftTest
{
    string file;
    string[] marmosConvertArgs;
    bool allowAutomaticPermutations;
}

void loadAndRunTest(string testDir, bool refresh)
{
    import std.file : readText;
    import std.path : buildNormalizedPath;
    import std.json : parseJSON;

    import marmos.converter.json : jsonToDoc;

    const configPath = buildNormalizedPath(testDir, "config.json");
    infof("loading config from: %s", configPath);

    auto configJson = readText(configPath).parseJSON;
    auto config = jsonToDoc!Config(configJson);

    config.test.match!(
        (SingleFileDriftTest sft)
        { 
            if(sft.allowAutomaticPermutations)
            {
                singleFileTest(testDir, config, sft, "_autoperm-semanticPassTrue", ["--feature-semanticPass=true"], refresh); // @suppress(dscanner.style.long_line)
                singleFileTest(testDir, config, sft, "_autoperm-semanticPassFalse", ["--feature-semanticPass=false"], refresh); // @suppress(dscanner.style.long_line)
            }
            else
            {
                singleFileTest(testDir, config, sft, "as-is", [], refresh);
            }
        }
    );
}

private void singleFileTest(string testDir, Config config, SingleFileDriftTest test, string resultSubdir, string[] extraArgs, bool refresh) // @suppress(dscanner.style.long_line)
{
    import std.file : readText, exists, copy, mkdirRecurse;
    import std.path : buildNormalizedPath;
    import std.json : parseJSON;

    import marmos.converter.command; // Intentionally everything

    infof("running single file test: %s", test);

    const tempResultFile = buildNormalizedPath(testDir, resultSubdir, "_temp_result.json");
    const mainResultFile = buildNormalizedPath(testDir, resultSubdir, "_result.json");
    mkdirRecurse(buildNormalizedPath(testDir, resultSubdir));

    infof("tempResultFile is at %s", tempResultFile);
    infof("mainResultFile is at %s", mainResultFile);

    ConvertCommand command;
    auto args = [
        buildNormalizedPath(testDir, test.file), // Input file
        "--output-dir=" ~ tempResultFile,
        "--output-style=singleFile",
        "--pretty"
    ];
    args ~= test.marmosConvertArgs;
    args ~= extraArgs;

    infof("using args for marmos convert: %s", args);

    enforce(CLI!ConvertCommand.parseArgs(command, args));
    enforce(runConvert(command) == 0);

    if(!mainResultFile.exists)
    {
        infof("mainResultFile doesn't exist, copying tempResultFile over and passing test");
        copy(tempResultFile, mainResultFile);
        return;
    }

    infof("reading results and comparing");
    const tempResultJson = readText(tempResultFile).parseJSON;
    const mainResultJson = readText(mainResultFile).parseJSON;

    // I feel doing a JSON compare rather than converting into the doc model first an just using opEquals, is more correct.
    if(!refresh)
        enforceJsonValuesSame(tempResultJson, mainResultJson);
    copy(tempResultFile, mainResultFile);
}

private void enforceJsonValuesSame(JSONValue temp, JSONValue main)
{
    // NOTE: While JSONValue does implement opEquals, we want to provide more detailed error messages

    bool passed = true;
    compare(temp, main, "", passed);
    enforce(passed, "temp results and main results differ - refer to error logs");
}

private void compare(
    JSONValue temp,
    JSONValue main,
    string jsonPath,
    scope ref bool passed
)
{
    tracef("comparing %s", jsonPath);

    if(temp.type != main.type)
    {
        errorf("[%s] temp and main have a type mismatch, temp is %s whereas main is %s", jsonPath, temp.type, main.type); // @suppress(dscanner.style.long_line)
        passed = false;
        return;
    }

    if(temp.type == JSONType.object)
    {
        compareObjects(temp.objectNoRef, main.objectNoRef, jsonPath, passed);
        return;
    }
    else if(temp.type == JSONType.array)
    {
        compareArrays(temp.arrayNoRef, main.arrayNoRef, jsonPath, passed);
        return;
    }

    // They're both a primitive type we can just use opEquals on
    if(temp != main)
    {
        errorf("[%s] temp and main have a value mismatch, temp is (%s) %s whereas main is (%s) %s", jsonPath, temp.type, temp, main.type, main); // @suppress(dscanner.style.long_line)
        passed = false;
        return;
    }
}

private void compareObjects(
    JSONValue[string] tempObj, 
    JSONValue[string] mainObj, 
    string jsonPath, 
    scope ref bool passed
)
{
    import std.algorithm : filter;

    tracef("comparing %s", jsonPath);

    if(tempObj.length < mainObj.length)
    {
        auto missingKeys = mainObj.byKey.filter!(key => !(key in tempObj));
        errorf("[%s] key mismatch, main has more keys than temp: %s", jsonPath, missingKeys);
        passed = false;
        return;
    }
    else if(tempObj.length > mainObj.length)
    {
        auto missingKeys = tempObj.byKey.filter!(key => !(key in mainObj));
        errorf("[%s] key mismatch, temp has more keys than main: %s", jsonPath, missingKeys);
        passed = false;
        return;
    }

    foreach(key; tempObj.byKey)
    {
        if(!(key in mainObj))
        {
            errorf("[%s] key missing, main is missing the following key that temp has: %s", jsonPath, key);
            passed = false;
            continue;
        }

        compare(tempObj[key], mainObj[key], jsonPath~"."~key, passed);
    }
}

private void compareArrays(
    JSONValue[] tempArr, 
    JSONValue[] mainArr, 
    string jsonPath, 
    scope ref bool passed
)
{
    import std.format : format;

    tracef("comparing %s", jsonPath);

    if(tempArr.length != mainArr.length)
    {
        errorf("[%s] array length mismatch, temp has %s items whereas main has %s items", jsonPath, tempArr.length, mainArr.length); // @suppress(dscanner.style.long_line)
        passed = false;
        return;
    }

    foreach(i; 0..tempArr.length)
        compare(tempArr[i], mainArr[i], format("%s[%s]", jsonPath, i), passed);
}