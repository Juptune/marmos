load('ext://uibutton', 'cmd_button', 'text_input', 'choice_input')

#### Setup ####

local('''
    if [ ! -d build ]; then
        meson setup build
    fi
''')

#### Development ####

local_resource(
    'unittests',
    cmd='meson test -C build --suite unittest && meson compile -C build || cat build/meson-logs/testlog.txt',
    deps=['meson.build', 'src/', 'subprojects/packagefiles/'],
    labels=['development']
)
cmd_button(
    'unittest:open-logs',
    resource='unittests',
    text='Open logs',
    argv=['bash', '-c', '$GUI_EDITOR build/meson-logs/testlog.txt'],
    inputs=[text_input('GUI_EDITOR', 'Editor', default='code')]
)

local_resource(
    'doc-tests',
    cmd='meson test -C build --suite doc-tests || cat build/meson-logs/testlog.txt',
    labels=['development']
)
cmd_button(
    'doc-tests:choose',
    resource='doc-tests',
    text='Run Test',
    argv=['bash', '-c', 'cd build; ./marmos-test --test-dir ../tests/$TEST_NAME'],
    inputs=[text_input('TEST_NAME', 'Test Name')]
)
cmd_button(
    'doc-tests:diff',
    resource='doc-tests',
    text='Diff Test',
    argv=['bash', '-c', 'diff tests/$TEST_NAME/expected.json tests/$TEST_NAME/got.json'],
    inputs=[text_input('TEST_NAME', 'Test Name')]
)
cmd_button(
    'doc-tests:update',
    resource='doc-tests',
    text='Update Test',
    argv=['bash', '-c', 'mv tests/$TEST_NAME/got.json tests/$TEST_NAME/expected.json'],
    inputs=[text_input('TEST_NAME', 'Test Name')],
    requires_confirmation=True
)

#### TypeScript Dogfooding ####

local_resource(
    'typescript:generate',
    cmd=['bash', '-c', './build/marmos generate-typescript --format --output-file dogfood/typescript/src/marmos.ts'],
    resource_deps=['unittests'],
    labels=['typescript'],
    deps=['./build/marmos'],
    auto_init=False,
)

local_resource(
    'typescript:test',
    cmd=['bash', '-c', '''
        if [ ! -d node_modules ]; then
            pnpm install
        fi

        pnpm run test
        pnpm run build
    '''],
    labels=['typescript'],
    deps=['dogfood/typescript/package.json', 'dogfood/typescript/tsconfig.json', 'dogfood/typescript/src/', 'dogfood/typescript/test/'],
    resource_deps=['typescript:generate'],
    dir='dogfood/typescript/',
    auto_init=False,
)
cmd_button(
    'typescript:test:convert',
    resource='typescript:test',
    text='Run Convert',
    argv=['bash', '-c', '''
        set -euo pipefail
        cd dogfood/typescript
        ../../build/marmos generate-generic --output-file marmos_test.json $INPUT_FILE
        ./bin/dev.js convert marmos_test.json
    '''],
    inputs=[
        text_input('INPUT_FILE', 'Input File'),
    ]
)

local_resource(
    'typescript:test-juptune',
    serve_cmd=['bash', '-c', '''
        set -euo pipefail
        mkdir -p _test/docfx
        cd _test

        for file in $(find ../../../../juptune/src/ -name '*.d'); do
            ../../../build/marmos generate-generic $file
        done

        rm -rf docfx/juptune
        ../bin/dev.js convert *.json --outputFolder docfx/
        cd docfx
        docfx --serve
    '''],
    labels=['typescript'],
    resource_deps=['typescript:test'],
    serve_dir='dogfood/typescript/',
    auto_init=False,
    trigger_mode=TRIGGER_MODE_MANUAL,
    links=['http://localhost:8080'],
)

#### Manual Actions ####

local_resource(
    '[DevOps]',
    cmd='echo "Please use the buttons provided to perform different operations."',
    labels=['zzz_manual'],
)