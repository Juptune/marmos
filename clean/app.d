/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
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