typescript
=================

A new CLI generated with oclif


[![oclif](https://img.shields.io/badge/cli-oclif-brightgreen.svg)](https://oclif.io)
[![Version](https://img.shields.io/npm/v/typescript.svg)](https://npmjs.org/package/typescript)
[![Downloads/week](https://img.shields.io/npm/dw/typescript.svg)](https://npmjs.org/package/typescript)


<!-- toc -->
* [Usage](#usage)
* [Commands](#commands)
<!-- tocstop -->
# Usage
<!-- usage -->
```sh-session
$ npm install -g typescript
$ marmos-docfx COMMAND
running command...
$ marmos-docfx (--version)
typescript/0.0.0 linux-x64 node-v20.12.1
$ marmos-docfx --help [COMMAND]
USAGE
  $ marmos-docfx COMMAND
...
```
<!-- usagestop -->
# Commands
<!-- commands -->
* [`marmos-docfx hello PERSON`](#marmos-docfx-hello-person)
* [`marmos-docfx hello world`](#marmos-docfx-hello-world)
* [`marmos-docfx help [COMMAND]`](#marmos-docfx-help-command)
* [`marmos-docfx plugins`](#marmos-docfx-plugins)
* [`marmos-docfx plugins add PLUGIN`](#marmos-docfx-plugins-add-plugin)
* [`marmos-docfx plugins:inspect PLUGIN...`](#marmos-docfx-pluginsinspect-plugin)
* [`marmos-docfx plugins install PLUGIN`](#marmos-docfx-plugins-install-plugin)
* [`marmos-docfx plugins link PATH`](#marmos-docfx-plugins-link-path)
* [`marmos-docfx plugins remove [PLUGIN]`](#marmos-docfx-plugins-remove-plugin)
* [`marmos-docfx plugins reset`](#marmos-docfx-plugins-reset)
* [`marmos-docfx plugins uninstall [PLUGIN]`](#marmos-docfx-plugins-uninstall-plugin)
* [`marmos-docfx plugins unlink [PLUGIN]`](#marmos-docfx-plugins-unlink-plugin)
* [`marmos-docfx plugins update`](#marmos-docfx-plugins-update)

## `marmos-docfx hello PERSON`

Say hello

```
USAGE
  $ marmos-docfx hello PERSON -f <value>

ARGUMENTS
  PERSON  Person to say hello to

FLAGS
  -f, --from=<value>  (required) Who is saying hello

DESCRIPTION
  Say hello

EXAMPLES
  $ marmos-docfx hello friend --from oclif
  hello friend from oclif! (./src/commands/hello/index.ts)
```

_See code: [src/commands/hello/index.ts](https://github.com/Juptune/marmos/blob/v0.0.0/src/commands/hello/index.ts)_

## `marmos-docfx hello world`

Say hello world

```
USAGE
  $ marmos-docfx hello world

DESCRIPTION
  Say hello world

EXAMPLES
  $ marmos-docfx hello world
  hello world! (./src/commands/hello/world.ts)
```

_See code: [src/commands/hello/world.ts](https://github.com/Juptune/marmos/blob/v0.0.0/src/commands/hello/world.ts)_

## `marmos-docfx help [COMMAND]`

Display help for marmos-docfx.

```
USAGE
  $ marmos-docfx help [COMMAND...] [-n]

ARGUMENTS
  COMMAND...  Command to show help for.

FLAGS
  -n, --nested-commands  Include all nested commands in the output.

DESCRIPTION
  Display help for marmos-docfx.
```

_See code: [@oclif/plugin-help](https://github.com/oclif/plugin-help/blob/v6.2.3/src/commands/help.ts)_

## `marmos-docfx plugins`

List installed plugins.

```
USAGE
  $ marmos-docfx plugins [--json] [--core]

FLAGS
  --core  Show core plugins.

GLOBAL FLAGS
  --json  Format output as json.

DESCRIPTION
  List installed plugins.

EXAMPLES
  $ marmos-docfx plugins
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/index.ts)_

## `marmos-docfx plugins add PLUGIN`

Installs a plugin into marmos-docfx.

```
USAGE
  $ marmos-docfx plugins add PLUGIN... [--json] [-f] [-h] [-s | -v]

ARGUMENTS
  PLUGIN...  Plugin to install.

FLAGS
  -f, --force    Force npm to fetch remote resources even if a local copy exists on disk.
  -h, --help     Show CLI help.
  -s, --silent   Silences npm output.
  -v, --verbose  Show verbose npm output.

GLOBAL FLAGS
  --json  Format output as json.

DESCRIPTION
  Installs a plugin into marmos-docfx.

  Uses npm to install plugins.

  Installation of a user-installed plugin will override a core plugin.

  Use the MARMOS_DOCFX_NPM_LOG_LEVEL environment variable to set the npm loglevel.
  Use the MARMOS_DOCFX_NPM_REGISTRY environment variable to set the npm registry.

ALIASES
  $ marmos-docfx plugins add

EXAMPLES
  Install a plugin from npm registry.

    $ marmos-docfx plugins add myplugin

  Install a plugin from a github url.

    $ marmos-docfx plugins add https://github.com/someuser/someplugin

  Install a plugin from a github slug.

    $ marmos-docfx plugins add someuser/someplugin
```

## `marmos-docfx plugins:inspect PLUGIN...`

Displays installation properties of a plugin.

```
USAGE
  $ marmos-docfx plugins inspect PLUGIN...

ARGUMENTS
  PLUGIN...  [default: .] Plugin to inspect.

FLAGS
  -h, --help     Show CLI help.
  -v, --verbose

GLOBAL FLAGS
  --json  Format output as json.

DESCRIPTION
  Displays installation properties of a plugin.

EXAMPLES
  $ marmos-docfx plugins inspect myplugin
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/inspect.ts)_

## `marmos-docfx plugins install PLUGIN`

Installs a plugin into marmos-docfx.

```
USAGE
  $ marmos-docfx plugins install PLUGIN... [--json] [-f] [-h] [-s | -v]

ARGUMENTS
  PLUGIN...  Plugin to install.

FLAGS
  -f, --force    Force npm to fetch remote resources even if a local copy exists on disk.
  -h, --help     Show CLI help.
  -s, --silent   Silences npm output.
  -v, --verbose  Show verbose npm output.

GLOBAL FLAGS
  --json  Format output as json.

DESCRIPTION
  Installs a plugin into marmos-docfx.

  Uses npm to install plugins.

  Installation of a user-installed plugin will override a core plugin.

  Use the MARMOS_DOCFX_NPM_LOG_LEVEL environment variable to set the npm loglevel.
  Use the MARMOS_DOCFX_NPM_REGISTRY environment variable to set the npm registry.

ALIASES
  $ marmos-docfx plugins add

EXAMPLES
  Install a plugin from npm registry.

    $ marmos-docfx plugins install myplugin

  Install a plugin from a github url.

    $ marmos-docfx plugins install https://github.com/someuser/someplugin

  Install a plugin from a github slug.

    $ marmos-docfx plugins install someuser/someplugin
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/install.ts)_

## `marmos-docfx plugins link PATH`

Links a plugin into the CLI for development.

```
USAGE
  $ marmos-docfx plugins link PATH [-h] [--install] [-v]

ARGUMENTS
  PATH  [default: .] path to plugin

FLAGS
  -h, --help          Show CLI help.
  -v, --verbose
      --[no-]install  Install dependencies after linking the plugin.

DESCRIPTION
  Links a plugin into the CLI for development.
  Installation of a linked plugin will override a user-installed or core plugin.

  e.g. If you have a user-installed or core plugin that has a 'hello' command, installing a linked plugin with a 'hello'
  command will override the user-installed or core plugin implementation. This is useful for development work.


EXAMPLES
  $ marmos-docfx plugins link myplugin
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/link.ts)_

## `marmos-docfx plugins remove [PLUGIN]`

Removes a plugin from the CLI.

```
USAGE
  $ marmos-docfx plugins remove [PLUGIN...] [-h] [-v]

ARGUMENTS
  PLUGIN...  plugin to uninstall

FLAGS
  -h, --help     Show CLI help.
  -v, --verbose

DESCRIPTION
  Removes a plugin from the CLI.

ALIASES
  $ marmos-docfx plugins unlink
  $ marmos-docfx plugins remove

EXAMPLES
  $ marmos-docfx plugins remove myplugin
```

## `marmos-docfx plugins reset`

Remove all user-installed and linked plugins.

```
USAGE
  $ marmos-docfx plugins reset [--hard] [--reinstall]

FLAGS
  --hard       Delete node_modules and package manager related files in addition to uninstalling plugins.
  --reinstall  Reinstall all plugins after uninstalling.
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/reset.ts)_

## `marmos-docfx plugins uninstall [PLUGIN]`

Removes a plugin from the CLI.

```
USAGE
  $ marmos-docfx plugins uninstall [PLUGIN...] [-h] [-v]

ARGUMENTS
  PLUGIN...  plugin to uninstall

FLAGS
  -h, --help     Show CLI help.
  -v, --verbose

DESCRIPTION
  Removes a plugin from the CLI.

ALIASES
  $ marmos-docfx plugins unlink
  $ marmos-docfx plugins remove

EXAMPLES
  $ marmos-docfx plugins uninstall myplugin
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/uninstall.ts)_

## `marmos-docfx plugins unlink [PLUGIN]`

Removes a plugin from the CLI.

```
USAGE
  $ marmos-docfx plugins unlink [PLUGIN...] [-h] [-v]

ARGUMENTS
  PLUGIN...  plugin to uninstall

FLAGS
  -h, --help     Show CLI help.
  -v, --verbose

DESCRIPTION
  Removes a plugin from the CLI.

ALIASES
  $ marmos-docfx plugins unlink
  $ marmos-docfx plugins remove

EXAMPLES
  $ marmos-docfx plugins unlink myplugin
```

## `marmos-docfx plugins update`

Update installed plugins.

```
USAGE
  $ marmos-docfx plugins update [-h] [-v]

FLAGS
  -h, --help     Show CLI help.
  -v, --verbose

DESCRIPTION
  Update installed plugins.
```

_See code: [@oclif/plugin-plugins](https://github.com/oclif/plugin-plugins/blob/v5.3.2/src/commands/plugins/update.ts)_
<!-- commandsstop -->
