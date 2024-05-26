#### Project configuration ####

project(
    'marmos', 
    'd',
    license: 'MPL-2.0',
    version: '0.0.1',
)

#### Sources ####

marmos_lib_srcs = files(
    './src/marmos/generic/docparser.d',
    './src/marmos/generic/model.d',
    './src/marmos/generic/visitor.d',
    
    './src/marmos/output/json.d',

    './src/marmos/package.d',
)

marmos_test_dirs = [
    'blocks/equal-list',
    'blocks/paragraph',
    'blocks/ordered-list',
    'blocks/unordered-list',

    'inlines/bold',
    'inlines/code',
    'inlines/italic',
    'inlines/text',

    'syntax/alias-basic',
    'syntax/class-basic',
    'syntax/enum-basic',
    'syntax/function-basic',
    'syntax/interface-basic',
    'syntax/module-basic',
    'syntax/struct-basic',
    'syntax/template-basic',
    'syntax/template-mixin-basic',
    'syntax/union-basic',
    'syntax/variable-basic',
]

#### Dependencies ####

dmd_dep = subproject('dmd-fe').get_variable('dmd_dep')

marmos_lib_dep = declare_dependency(
    include_directories: include_directories('src'),
    sources: marmos_lib_srcs,
)

marmos_all_dep = declare_dependency(
    dependencies: [marmos_lib_dep, dmd_dep],
)

marmos_exe_dep = declare_dependency(
    sources: './src/marmos/main.d',
    dependencies: [marmos_all_dep],
)

marmos_unittest_dep = declare_dependency(
    sources: './src/dummy_main.d',
    dependencies: [marmos_all_dep],
)

marmos_test_dep = declare_dependency(
    sources: './src/marmos/test_main.d',
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
)

marmos_test_exe = executable(
    'marmos-test', 
    dependencies: [marmos_test_dep],
    d_module_versions: ['MesonTest'],
)

#### Install ####

#### Tests ####

test('marmos-unittest', marmos_unittest_exe, suite: 'unittest')

foreach dir : marmos_test_dirs
    test(
        'marmos-test-'+dir, 
        marmos_test_exe, 
        suite: 'doc-tests', 
        args: ['--test-dir', meson.current_source_dir()+'/tests/'+dir]
    )
endforeach