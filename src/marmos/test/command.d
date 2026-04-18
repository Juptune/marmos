/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.test.command;

import argparse : Command, PositionalArgument, Description;

@Command("test")
struct TestCommand
{
    @(
        PositionalArgument("test-dir")
        .Description("A directory containing a singular test to run.")
    )
    string testDir;
}

int runTest(TestCommand args)
{
	import marmos.converter.json : jsonToDoc;
	import marmos.test.runner : loadAndRunTest;

    try
	{
		loadAndRunTest(args.testDir);
		return 0;
	}
	catch(Exception ex)
	{
		import std.logger;
		errorf("Uncaught exception: %s", ex);
		return 1;
	}
}