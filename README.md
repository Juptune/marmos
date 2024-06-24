# Overview

Marmos is a tool for creating documentation files for D source code, that can then be ingested into some other tool, such as a documentation generator.

The rationale is that the native ddoc generation is insufficient due to its complete lack of native features required for a comprehensive documentation site, such as a search bar; navigation bar, etc.

Currently the D compilers do not have an easy to use way of generating a documented AST. While there **are** flags for creating a JSON dump of the AST it has several issues, the biggest one being that under common circumstances the documentation for AST nodes just doesn't get outputted...

Thus Marmos was born to help strive towards the goal of better documentation in D by acting as a bridge between the compiler's AST and external, existing tooling for generating the full HTML/PDFs/whatever.

# Building/Downloading Marmos

There's a few distros which Marmos already has packages for, but if you still want to build it locally then:

```bash
your-package-manager install meson

git clone https://github.com/Juptune/marmos
cd marmos
meson setup build --buildtype=release
cd build
ninja
install ./marmos /usr/local/bin/marmos
```

You can technically get this to work with dub as well, but honestly I don't care enough about dub to bother with it myself.

## Packages

| Package Name(s) | Distro              | Status                                                                                                                                                                                  |
| --------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `marmos`        | OpenSUSE Tumbleweed | [![build result](https://build.opensuse.org/projects/home:bchatha:juptune/packages/marmos/badge.svg?type=default)](https://build.opensuse.org/package/show/home:bchatha:juptune/marmos) |

# Features

- Uses dmd-as-a-library, so parsing is only as buggy as DMD's frontend is.
- Currently only performs up to syntax analysis - you don't need to feed the tool your entire compiler args just to make it work (e.g. since it doesn't need to lookup imports).
- Outputs typed JSON so there's no guessing what the object's fields are.
- Generates libraries for other languages for parsing the typed JSON (easier integration into other tooling).
- Output is a separate AST structure from the compiler's, to mitigate internal changes to AST structure.

# Roadmap/Wishlist

This is an ever changing list of stuff I want to work on. Whether I get around to it is another question...

- Add flags to optionally enable semantic passes that enrich the output
- Add additional "documentation friendly" helpers to the output, e.g. a simple array listing all symbols rather than expecting tools to traverse the entire documentation AST.
- Moar language support.
- Maybe add in more models than just the "generic" one, e.g. specifically target certain tools.

# Development

To streamline the main development workflows, a [Tiltfile](https://docs.tilt.dev/install.html) is provided (hint: `kubectl` and `ctlptl` are not actually required to install Tilt).

After installing tilt, you can simply run `tilt up && tilt down` within the root directory, and you'll benefit from the following:

- Automatic setup of the meson build directory.
- Automatic test runs on file save.
- Helper buttons and commands for various purposes (e.g. running stuff from [./devops/scripts](./devops/scripts/))

## Tests

Meson builds a test binary using the [test_main.d](./src/marmos/test_main.d) entrypoint. This test binary can be used to target any of the tests within the [tests](./tests/) directory.

This test binary performs the following:

- It will generate a documentation AST for the `main.d` file within the target directory.
  - This AST is slightly different than a normal one, as specific fields (such as filenames) are blanked out.
- It will compare the raw JSON output with the `expected.json` file within the target directory. The test passes if these two JSON strings match.
- If it fails, it will output a `got.json` file within the target directory, allowing inspection of where things differ.

In the future I'd like to implement a proper json-aware compare for better diagnostics, but this is good enough for now.

You can add a test by making a new test folder and adding it into the [meson.build](./meson.build) file.

## Tooling

Required:

- meson

Optionally:

- act (used by Tilt to test our Github Actions)
- tilt

## Packaging

### OpenSUSE

The .spec file for the OpenSUSE RPM build is located at [devops/pkg/opensuse-rpm/marmos.spec](./devops/pkg/opensuse-rpm/marmos.spec).

The main development project on OBS (Open Build Service) is [home:bchatha:juptune](https://build.opensuse.org/project/show/home:bchatha:juptune), and the root package name for this repo is simply `marmos`.

OBS' Github webhook integration is enabled, and the uses the common Juptune org-wide [workflow](https://github.com/Juptune/distribution/blob/master/open-build-service/workflows.yml). Please review the distribution repo's README for more information on how the workflow... works.

Juptune is not currently part of the core distribution project.
