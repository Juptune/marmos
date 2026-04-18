#### Project configuration ####

project(
    'marmos', 
    'd',
    license: 'MPL-2.0',
    version: '0.0.1',
)

#### Sources ####

marmos_lib_srcs = files(
    './src/marmos/converter/command.d',
    './src/marmos/converter/common.d',
    './src/marmos/converter/convert.d',
    './src/marmos/converter/docparser.d',
    './src/marmos/converter/json.d',
    './src/marmos/converter/model.d',
    './src/marmos/converter/package.d',
    './src/marmos/converter/visitors.d',

    './src/marmos/test/command.d',
    './src/marmos/test/package.d',
    './src/marmos/test/runner.d',

    './src/marmos/context.d',
)

#### Dependencies ####

dmd_dep = subproject('dmd-fe').get_variable('dmd_dep')
argparse_dep = dependency('argparse', version: '>=2.0.2', method: 'dub')

marmos_lib_dep = declare_dependency(
    include_directories: include_directories('src'),
    sources: marmos_lib_srcs,
)

marmos_all_dep = declare_dependency(
    dependencies: [marmos_lib_dep, dmd_dep],
)

marmos_exe_dep = declare_dependency(
    sources: './src/app.d',
    dependencies: [marmos_all_dep, argparse_dep],
)

marmos_unittest_dep = declare_dependency(
    sources: './src/dummy_main.d',
    dependencies: [marmos_all_dep],
)

#### Executables ####

marmos_exe = executable(
    'marmos', 
    dependencies: [marmos_exe_dep],
    install: true,
)

#### Install ####

#### Tests ####

test_dirs = [
    './tests/typerefs/basic',
]

foreach test_dir : test_dirs
    # Convert e.g. './tests/typerefs/basic' -> 'marmos-unittest-typerefs-basic'
    subdir = test_dir.substring(8)
    subdirs = subdir.split('/')
    test_name = 'marmos-unittest'
    foreach dir : subdirs
        test_name += '-' + dir
    endforeach

    test(test_name, marmos_exe, suite: 'drift-tests', args: ['test', '../'+test_dir])
endforeach
