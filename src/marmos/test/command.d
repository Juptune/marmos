/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.test.command;

import argparse : Command, PositionalArgument, NamedArgument, Description;

@Command("test")
struct TestCommand
{
    @(
        PositionalArgument("test-dir")
        .Description("A directory containing a singular test to run.")
    )
    string testDir;

	@(
		NamedArgument("refresh")
		.Description("If specified, then the test will forcefully be passed, allowing for any 'main' result files to be updated.") // @suppress(dscanner.style.long_line)
	)
	bool refresh = false;
}

int runTest(TestCommand args)
{
	import marmos.converter.json : jsonToDoc;
	import marmos.test.runner : loadAndRunTest;

    try
	{
		loadAndRunTest(args.testDir, args.refresh);
		return 0;
	}
	catch(Exception ex)
	{
		import std.logger;
		errorf("Uncaught exception: %s", ex);
		return 1;
	}
}