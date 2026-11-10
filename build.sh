#!/usr/bin/env bash

echo "Cleaning up..."
rm -rf FLEX/ src/

echo "Copying sources..."
mkdir src/
git clone --depth=1 https://github.com/FLEXTool/FLEX
find FLEX/Classes -type f \( -name "*.h" -o -name "*.m" -o -name "*.mm" -o -name "*.c" \) -exec cp {} src/ \;

FILE="src/FLEXSwiftInternal.mm"
sed -i '' '59s/std::atomic<mask_t> _maybeMask;/mask_t _maybeMask;/' "$FILE"
sed -i '' '65s/std::atomic<preopt_cache_t \*> _originalPreoptCache;/preopt_cache_t * _originalPreoptCache;/' "$FILE"

make package
