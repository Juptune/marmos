# NOTE: Please uncomment the final line in dustmite.bash (and comment the line just above it.)

rm -rf clean.reduced clean.test
dub run dustmite -- --reduce-only=marmos/converter/docparser.d --reduce-only=marmos/converter/json.d --reduce-only=marmos/converter/model.d --reduce-only=marmos/converter/package.d --reduce-only=marmos/docs/config_models.d --reduce-only=marmos/docs/command.d --reduce-only=marmos/docs/discover.d --reduce-only=marmos/docs/html_generator.d --reduce-only=marmos/docs/package.d --reduce-only=marmos/docs/staging_generator.d ./clean/ 'bash ./dustmite.bash'