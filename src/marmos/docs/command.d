/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
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

	import marmos.converter.json 			: jsonToDoc, docToJson;
	import marmos.docs.config_models  		: MardocsConfig;
	import marmos.docs.discover  			: discoverSite, loadJsonModel, discoverStagingSite;
	import marmos.docs.html_generator		: generateSite;
	import marmos.docs.staging_generator	: generateAndEmitNavbar, generateAndEmitGroupStagingFiles;

	try
	{
		// Load config
		const mardocsPath = buildNormalizedPath(args.dir, "mardocs.json");
		enforce(mardocsPath.exists, format("Config file not found: %s - you can use --dir to change which directory to look in, or try out `marmos docs init`", mardocsPath)); // @suppress(dscanner.style.long_line)
		auto config = loadJsonModel!MardocsConfig(mardocsPath);

		// Discover input
		auto siteRoot = discoverSite(buildNormalizedPath(args.dir), config);

		// Generate staging output
		enforce(
			siteRoot.stagingDir != "/" 
			&& siteRoot.stagingDir.endsWith("staging") 
			&& buildNormalizedPath(siteRoot.stagingDir) != buildNormalizedPath(getcwd())
			, "failsafe triggered: " ~ siteRoot.stagingDir
		); // Make sure we don't accidentally delete folders we shouldn't.
		if(exists(siteRoot.stagingDir))
			rmdirRecurse(siteRoot.stagingDir);
		generateAndEmitNavbar(siteRoot);
		foreach(group; siteRoot.rootGroups)
			generateAndEmitGroupStagingFiles(siteRoot, group);

		// Discover staging input & generate HTML output
		discoverStagingSite(siteRoot);
		enforce(
			siteRoot.buildDir != "/" 
			&& siteRoot.buildDir.endsWith("build") 
			&& buildNormalizedPath(siteRoot.buildDir) != buildNormalizedPath(getcwd())
			, "failsafe triggered: " ~ siteRoot.buildDir
		);
		if(exists(siteRoot.buildDir))
			rmdirRecurse(siteRoot.buildDir);

		generateSite(siteRoot);

		return 0;
	}
	catch(Exception ex)
	{
		import std.logger;
		errorf("Uncaught exception: %s", ex);
		return 1;
	}
}