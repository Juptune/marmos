/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.command;

import argparse : Command, PositionalArgument, NamedArgument, Description, ArgumentGroup;

import marmos.context 			: MarmosContext;
import marmos.converter.convert : convertModuleToDocModel;
import marmos.converter.json    : docToJson;

@Command("convert")
struct ConvertCommand
{
	enum OutputStyle
	{
		FAILSAFE,
		singleFile
	}

	@ArgumentGroup("Features")
	{
		@(
			NamedArgument("feature-semanticPass")
			.Description("If enabled, marmos will perform semantic analysis on all specified source files, which provides enhanced output.\n\nNOTE: The version of DRuntime specified in either the .conf file, or via -i, MUST be compatible with the version of dmd-fe marmos is built against.\n\n`-i` is evaluated before the .conf, so you can try to specify an alternative DRuntime as an override.") // @suppress(dscanner.style.long_line)
		)
		bool useFeatureSemanticPass = false;
	}

	@ArgumentGroup("Compiler/dmd-fe options")
	{
		@(
			NamedArgument("use-default-conf")
			.Description("If enabled (which it is by defualt), allows dmd-fe to figure out the default compiler & its associated .conf file") // @suppress(dscanner.style.long_line)
		)
		bool useDefaultConfig = true;

		@(
			NamedArgument("i", "import-paths")
			.Description("Additional import paths, on top of the ones from the .conf file")
		)
		string[] importPaths;

		@(
			NamedArgument("J", "string-import-paths")
			.Description("Additional string import paths, on top of the ones from the .conf file")
		)
		string[] stringImportPaths;
	}
	
	@ArgumentGroup("Output options")
	{
		@(
			NamedArgument("o", "output-dir")
			.Description("Directory to store output files into - marmos will attempt to recursively create this directory, and any subdirectories it requires") // @suppress(dscanner.style.long_line)
		)
		string outputDir;

		@(
			NamedArgument("oS", "output-style")
			.Description("Controls how files are output.\n\nsingleFile will treat `-o` as a file path rather than a directory path, and output a single file there. Only usable if a single input file is found.")
		)
		OutputStyle outputStyle = OutputStyle.singleFile;
	}

	@(
		PositionalArgument("files-to-convert")
		.Description("Absolute or relative file paths, to either files or directories (MUST end in /) that should be converted into marmos models. Directories are NOT recursively searched.") // @suppress(dscanner.style.long_line)
	)
	string[] filesToConvert;
}

int runConvert(ConvertCommand args)
{
	import std.exception 	: enforce;
	import std.file 		: writeText = write, mkdirRecurse;
	import std.path 		: buildNormalizedPath, dirName;
	import std.json 		: toJSON;

	try
	{
		auto context = new MarmosContext();
		context.addImportPath(args.importPaths);
		context.addStringImportPath(args.stringImportPaths);
		context.useDefaultConf = args.useDefaultConfig;

		if(args.useFeatureSemanticPass)
			context.enableFeature(MarmosContext.Features.semanticPass);

		context.setupDmd();
		foreach(file; args.filesToConvert)
			context.parseModule(file);
		context.onDoneParsing();

		auto docModels = context.convertAllToDocModel();

		if(args.outputStyle == ConvertCommand.OutputStyle.singleFile)
		{
			enforce(docModels.length == 1, "`--output-style singleFile` can only be used when a SINGLE input file is provided");
			mkdirRecurse(args.outputDir.dirName);

			auto jsonModel = docModels[0].docToJson;
			writeText(args.outputDir, jsonModel.toJSON(pretty: true)); // outputDir is a file path in this case, not a dir path
		}
		else
		{
			foreach(model; docModels)
			{
			}
		}

		return 0;
	}
	catch(Exception ex)
	{
		import std.logger;
		errorf("Uncaught exception: %s", ex);
		return 1;
	}
}