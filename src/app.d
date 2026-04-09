import std.stdio;

import argparse : CLI, PositionalArgument, NamedArgument, Description, ArgumentGroup;

import marmos.context : MarmosContext;

struct MainCommand
{
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

	@(
		PositionalArgument("files-to-convert")
		.Description("Absolute or relative file paths, to either files or directories (MUST end in /) that should be converted into marmos models. Directories are NOT recursively searched.") // @suppress(dscanner.style.long_line)
	)
	string[] filesToConvert;
}

mixin CLI!MainCommand.main!((args)
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

	return 0;
});