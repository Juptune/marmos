#### Project configuration ####

project(
    'marmos', 
    'd',
    license: 'MPL-2.0',
    version: '0.0.1',
)

#### Sources ####

marmos_lib_srcs = files(
    './src/marmos/converter/convert.d',
    './src/marmos/converter/model.d',
    './src/marmos/converter/package.d',
    './src/marmos/converter/visitors.d',

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

marmos_unittest_exe = executable(
    'marmos-unittest', 
    dependencies: [marmos_unittest_dep],
    d_unittest: true,
)

marmos_exe = executable(
    'marmos', 
    dependencies: [marmos_exe_dep],
    install: true,
)

#### Install ####

#### Tests ####

test('marmos-unittest', marmos_unittest_exe, suite: 'unittest')