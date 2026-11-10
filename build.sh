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

# Export the built dylib alongside the deb (ESign injects .dylib more reliably)
DY="$(find .theos/obj -name 'autoflex.dylib' | head -n1)"
if [ -n "$DY" ]; then
  mkdir -p packages
  cp "$DY" packages/autoflex.dylib || true
  lipo -info packages/autoflex.dylib || true
else
  echo "WARNING: no autoflex.dylib found in .theos/obj"
fi

# Report exactly what will be uploaded
echo "--- packaged artifacts ---"
ls -la packages/ || true
