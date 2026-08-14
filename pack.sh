#!/bin/sh
set -e

# Build both architectures. Requires koxtoolchain bin dirs in PATH:
#   ~/x-tools/arm-kindlehf-linux-gnueabihf/bin
#   ~/x-tools/arm-kindlepw2-linux-gnueabi/bin

VERSION=$(jq -r '.version | join(".")' kpm/manifest.json)

# kindlepw2 only: libcjson.so (fw 5.16.2.1.1) lacks convenience add functions (pre-1.6.0)
# kindlehf devices ship newer libcjson that has these natively — do NOT link the stub there
arm-kindlepw2-linux-gnueabi-gcc -c -o /tmp/cjson_addboolfixup_pw2.o stubs/cjson_addboolfixup.c
# kindlepw2 sysroot glibc 2.12 lacks getauxval (added in 2.16)
arm-kindlepw2-linux-gnueabi-gcc -c -o /tmp/getauxval_stub.o stubs/getauxval_stub.c

cargo build-hf
RUSTFLAGS="-C link-arg=/tmp/getauxval_stub.o -C link-arg=/tmp/cjson_addboolfixup_pw2.o" cargo build-pw2

rm -rf build dist
mkdir dist
mkdir -p build/kindlehf/bin build/kindlehf/lib
mkdir -p build/kindlepw2/bin build/kindlepw2/lib
cp kpm/install.sh kpm/install.sql kpm/manifest.json kpm/uninstall.sh kpm/uninstall.sql build/
cp target/armv7-unknown-linux-gnueabihf/release/kompanion_launcher build/kindlehf/bin/
cp target/armv7-unknown-linux-gnueabihf/release/libkompanion_extractor.so build/kindlehf/lib/
cp target/armv7-unknown-linux-gnueabi/release/kompanion_launcher build/kindlepw2/bin/
cp target/armv7-unknown-linux-gnueabi/release/libkompanion_extractor.so build/kindlepw2/lib/
(cd build && python3 -c "
import tarfile, os, sys
out = sys.argv[1]
with tarfile.open(out, 'w:gz', compresslevel=5) as tar:
    for name in sorted(os.listdir('.')):
        if not name.startswith('.'):
            tar.add(name)
" "../dist/kompanion-${VERSION}.kpkg")

rm -rf build
