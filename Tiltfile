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

#### Manual Actions ####

local_resource(
    '[DevOps]',
    cmd='echo "Please use the buttons provided to perform different operations."',
    labels=['zzz_manual'],
)