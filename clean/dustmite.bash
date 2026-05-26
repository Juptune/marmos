#!/usr/bin/bash

set -eu

ARGPARSE_DIR=$(dub describe argparse | jq -r .targets[0].buildSettings.importPaths[0])

rm -rf /tmp/marmos-dustmite
ldc2 \
    -J=../imports/ \
    -I=. \
    -I=$ARGPARSE_DIR \
    --d-debug \
    --of=/tmp/marmos-dustmite \
    ./app.d \
    ./marmos/converter/json.d ./marmos/converter/model.d ./marmos/docs/config_models.d ./marmos/docs/command.d ./marmos/docs/discover.d ./marmos/docs/staging_generator.d ./marmos/docs/staging_models.d \
    $(find $ARGPARSE_DIR -name "*.d") 

/tmp/marmos-dustmite docs generate -d ../scratchpad 2>&1 && echo "done"