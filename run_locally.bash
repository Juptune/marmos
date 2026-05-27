echo "Trying manually reduced version"
cd clean && bash dustmite.bash || true

echo "Trying dustmite reduced version"
cd ../clean.reduced && bash dustmite.bash || true