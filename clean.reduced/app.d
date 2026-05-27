import std.stdio;

import argparse : CLI, SubCommand, matchCmd;

import marmos.docs.command 		: DocsCommand, runDocs;

struct MainCommand
{
	SubCommand!(DocsCommand) subcommand;
}

mixin CLI!MainCommand.main!((args)
{
	int result;

	args.subcommand.matchCmd!(
		(DocsCommand cmd) { result = runDocs(cmd); },
	);

	return result;
});