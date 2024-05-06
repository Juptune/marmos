/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.main;

import marmos.generic.model, marmos.generic.visitor;

shared static this()
{
    import dmd.frontend : initDMD;
    initDMD();
}

void main()
{
    auto mod = parseInMemory(q{
        /++
         + This is a test module
         +
         + Authors:
         +  - John Doe
         + ++/
        module test;
    });

    import std.stdio;
    writeln(mod);
}

DocModule parseInMemory(const string code)
{
    import dmd.frontend : parseModule;
    auto result = parseModule("unittest", code);
    assert(!result.diagnostics.hasErrors, "Errors occurred during parsing");

    return DocVisitor.visitModule(result.module_);
}