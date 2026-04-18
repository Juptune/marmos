/*
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at https://mozilla.org/MPL/2.0/.
 * Author: Bradley Chatha
 */
module marmos.converter.convert;

import std.logger : warningf, infof;

import dmd.dmodule : Module;

import marmos.context : MarmosContext;
import marmos.converter.common : toStringFromBuffer, fqn, listFromDmdBitFlags;
import marmos.converter.model; // Intentionally everything
import marmos.converter.visitors : DefinitionVisitor;

DocModelRoot convertModuleToDocModel(Module mod, MarmosContext context)
{
    DocModelRoot root;

    const modFqn = toStringFromBuffer((ref buf) => mod.fullyQualifiedName(buf));
    infof("converting module '%s' into a doc model", modFqn);

    if(mod.members is null)
    {
        warningf("module '%s' has a null .members?", modFqn);
        return root;
    }

    scope visitor = new DefinitionVisitor(context, mod);
    foreach(member; *mod.members)
        member.accept(visitor);
    root.module_.nestedTypes = visitor.aggregateDefinitions;
    root.module_.members = visitor.unaryDefinitions;
    root.module_.fqnComponents = fqn(mod);
    root.features = listFromDmdBitFlags!DocFeatures(context.getFeatures());

    return root;
}