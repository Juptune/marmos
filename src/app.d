/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
import std.stdio;

import argparse : CLI, SubCommand, matchCmd;

import marmos.converter.command : ConvertCommand, runConvert;
import marmos.test.command 		: TestCommand, runTest;

struct MainCommand
{
	SubCommand!(ConvertCommand, TestCommand) subcommand;
}

mixin CLI!MainCommand.main!((args)
{
	int result;

	args.subcommand.matchCmd!(
		(ConvertCommand cmd) { result = runConvert(cmd); },
		(TestCommand cmd) { result = runTest(cmd); }
	);

	return result;
});