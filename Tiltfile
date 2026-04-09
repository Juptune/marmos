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