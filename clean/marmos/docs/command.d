module marmos.docs.command;

import argparse : Command, PositionalArgument, NamedArgument, Description, ArgumentGroup, SubCommand, matchCmd;

@Command("docs")
struct DocsCommand
{
	SubCommand!(GenerateCommand) subcommand;
}

@Command("generate")
struct GenerateCommand
{
	@(
		NamedArgument("d", "dir")
		.Description("Directory containing a mardocs.json file - defaults to the current directory.")
	)
	string dir = "./";
}

int runDocs( DocsCommand args)
{
	int result;
	args.subcommand.matchCmd!(
		(GenerateCommand cmd) { result = runGenerate(cmd); }
	);

	return result;
}

int runGenerate(GenerateCommand args)
{
	import std.algorithm    : endsWith;
	import std.exception 	: enforce;
	import std.file 		: DirEntry, SpanMode, dirEntries, readText, exists, rmdirRecurse, getcwd;
	import std.format		: format;
	import std.json 		: parseJSON;
	import std.logger		: infof;
	import std.path 		: buildNormalizedPath;

	import marmos.converter.json 			: jsonToDoc;
	import marmos.docs.config_models  		: MardocsConfig;
	import marmos.docs.discover  			: discoverSite, loadJsonModel;
	import marmos.docs.staging_generator	: generateAndEmitGroupStagingFiles;

	try
	{
		// Load config
		const mardocsPath = buildNormalizedPath(args.dir, "mardocs.json");
		auto config = loadJsonModel!MardocsConfig(mardocsPath);

		// Discover input
		auto siteRoot = discoverSite(buildNormalizedPath(args.dir), config);

		// Generate staging output
		foreach(group; siteRoot.rootGroups)
			generateAndEmitGroupStagingFiles(siteRoot, group);

		return 0;
	}
	catch(Exception ex)
	{
		import std.logger;
		errorf("Uncaught exception: %s", ex);
		return 1;
	}
}