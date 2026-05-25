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

    './src/marmos/docs/config_models.d',
    './src/marmos/docs/command.d',
    './src/marmos/docs/discover.d',
    './src/marmos/docs/html_generator.d',
    './src/marmos/docs/package.d',
    './src/marmos/docs/staging_generator.d',
    './src/marmos/docs/staging_models.d',

    './src/marmos/test/command.d',
    './src/marmos/test/package.d',
    './src/marmos/test/runner.d',

    './src/marmos/context.d',
)

#### Dependencies ####

subproject('dmd-phobos')
dmd_dep = subproject('dmd-fe').get_variable('dmd_dep')
argparse_dep = dependency('argparse', version: '>=2.0.2', method: 'dub')

marmos_lib_dep = declare_dependency(
    include_directories: include_directories('src'),
    sources: marmos_lib_srcs,
    d_import_dirs: ['./imports/']
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
    './tests/aggregates/class',
    './tests/aggregates/enum',
    './tests/aggregates/struct',
    './tests/aggregates/template',

    './tests/curiosity/string-mixin',

    './tests/typerefs/alias',
    './tests/typerefs/array',
    './tests/typerefs/associativeArray',
    './tests/typerefs/basic',
    './tests/typerefs/class',
    './tests/typerefs/enum',
    './tests/typerefs/function',
    './tests/typerefs/pointer',
    './tests/typerefs/struct',
    './tests/typerefs/template',
    './tests/typerefs/template-instance',
]

foreach test_dir : test_dirs
    # Convert e.g. './tests/typerefs/basic' -> 'marmos-unittest-typerefs-basic'
    subdir = test_dir.substring(8)
    subdirs = subdir.split('/')
    test_name = 'marmos-unittest'
    foreach dir : subdirs
        test_name += '-' + dir
    endforeach

    test(test_name, marmos_exe, suite: 'drift-tests', args: 
    [
        'test', '../'+test_dir, 
        '--refresh'
    ])
endforeach

# Dogfood test - try to do a semantic-enabled run of marmos' own code
dub_program = find_program('dub')
jq_program = find_program('jq', required: false)
if jq_program.found() and dub_program.found()
    argparse_import_path = run_command('bash', '-c', '''
        dub describe argparse | jq -r .targets[0].buildSettings.importPaths[0]
    ''').stdout().strip()

    test('dogfood', marmos_exe, suite: 'dogfood', args: [
        'convert',
        marmos_lib_srcs,
        '-o=../tests/dogfood-results',
        '--feature-semanticPass=true',
        '--use-default-conf=false', # We want to always use DMD's flavour of Phobos (because of course, LDC's version doesn't compile with DMD dmd-fe so we can't rely on the host compiler's Phobos, fml)
        '--pretty',
        '-i=../src/',
        '-i=../subprojects/dmd-fe/druntime/src/',
        '-i=../subprojects/dmd-fe/compiler/src/',
        '-i=../subprojects/dmd-phobos/',
        '-i=' + argparse_import_path,
        '-J=../subprojects/dmd-fe/compiler/src/dmd/res',
        '-J=../subprojects/dmd-fe/',
        '-J=../imports/',
    ])
else
    warning('JQ or dub is not installed - not enabling dogfood test')
endif
