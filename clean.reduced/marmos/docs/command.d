module marmos.docs.command;

import argparse : Command, NamedArgument, SubCommand, matchCmd;

@Command("docs")
struct DocsCommand
{
	SubCommand!(GenerateCommand) subcommand;
}

@Command("generate")
struct GenerateCommand
{
	@		NamedArgument("d")
	string dir ;
}

int runDocs( DocsCommand args)
{
	int result;
	args.subcommand.matchCmd!(
		(cmd) { runGenerate(cmd); }
	);

	return result;
}

int runGenerate(GenerateCommand args)
{
	import marmos.docs.config_models  		;
	import marmos.docs.discover  			;
	import marmos.docs.staging_generator	;

	try
	{
		auto config = MardocsConfig();

		// Discover input
		auto siteRoot = discoverSite(args.dir, config);

		// Generate staging output
		foreach(group; siteRoot.rootGroups)
			generateAndEmitGroupStagingFiles(siteRoot, group);

		return 0;
	}
	catch(Exception )
		return 1;
}