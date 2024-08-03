# Overview

Marmos is a tool for creating documentation files for D source code, that can then be ingested into some other tool, such as a documentation generator.

The rationale is that the native ddoc generation is insufficient due to its complete lack of native features required for a comprehensive documentation site, such as a search bar; navigation bar, etc.

Currently the D compilers do not have an easy to use way of generating a documented AST. While there **are** flags for creating a JSON dump of the AST it has several issues, the biggest one being that under common circumstances the documentation for AST nodes just doesn't get outputted...

Thus Marmos was born to help strive towards the goal of better documentation in D by acting as a bridge between the compiler's AST and external, existing tooling for generating the full HTML/PDFs/whatever.

# Getting Marmos

## Building From Source

There's a few distros which Marmos already has packages for - and even a docker image - but if you still want to build it locally then:

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

## Building the Docker Image

If you want to build the docker image locally rather than use the prebuilt image, then simply run the following

```bash
git clone https://github.com/Juptune/marmos
cd marmos
docker build -f devops/pkg/docker/Dockerfile -t marmos-local .
```

## Prebuilt Linux Packages

| Package Name(s) | Distro              | Status                                                                                                                                                                                  |
| --------------- | ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `marmos`        | OpenSUSE Tumbleweed | [![build result](https://build.opensuse.org/projects/home:bchatha:juptune/packages/marmos/badge.svg?type=default)](https://build.opensuse.org/package/show/home:bchatha:juptune/marmos) |

## Prebuild Docker Image

This image is currently hosted on [Docker Hub](https://hub.docker.com/r/bradchatha/marmos), and can be referenced under the name `bradchatha/marmos`.

For example:

```
docker run --rm -it -v $(pwd)/src/:/src/ bradchatha/marmos generate-generic /src/dummy_main.d --output-file /src/dummy_main.json
```

# Getting Started

Usage is very raw right now, if you'd like to see a premade script that creates an example site for Phobos and [Juptune](https://github.com/Juptune/juptune) then please see the demo site's script at: https://github.com/Juptune/marmos-docfx-demo/blob/5dd208cf0aca204147606f13c027942c21c5d743/update.sh

Otherwise the process is currently as follows:

* Download [docfx](https://dotnet.github.io/docfx/)

* Download/build marmos (if you build it, then your path to marmos will be `./build/marmos`)

```bash
# (If building locally)
alias marmos=$(pwd)/build/marmos
```

* Create a new folder anywhere you want, and initialise a docfx project in it:

```bash
mkdir -p /tmp/marmos_test/docfx
cd /tmp/marmos_test/docfx
docfx init # NOTE: Might want to disable PDF generation.
mkdir myapi
```

* Update the `toc.yml` file that gets created with the following:

```yaml
# NOTE: Marmos creates a folder for each module.
#
#       So in this example, since we have modules like `juptune.http`, `juptune.core`, etc.
#       marmos will generate `myapi/juptune/http/...`, `myapi/juptune/core/...`
#
#       Hence why you need to specify a subpath relevant to your project.
items:
  - name: API Reference
    href: myapi/juptune/ # The end slash is important
```

* Use marmos to generate a model for all the D files in your project:

```bash
cd /tmp/marmos_test
git clone https://github.com/Juptune/juptune

mkdir models
cd models

for file in $(find ../juptune -name "*.d"); do
  marmos generate-generic "$file"
done
```

* Use marmos-docfx to convert the models into docfx api pages:

```bash
cd /tmp/marmos_test
npx marmos-docfx convert models/*.json --outputFolder docfx/myapi
```

* Build the docfx site, and have a look around to make sure it's worked:

```bash
cd /tmp/marmos_test/docfx
docfx --serve # Open http://localhost:8080
```

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
