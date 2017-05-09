#!/bin/bash

build_exit_code=0
root=`pwd`
build="${root}/build"
log="${build}/build.log"
rm -f "${log}"
mkdir -p "${build}/bin"
mkdir -p "${root}/release/bin"

function build_osx_bin {
    local name=$1

    echo "building osx bin ${name}..."

    pushd "${name}" >&/dev/null
    xcodebuild -configuration Release -scheme "${name}" clean archive -archivePath "${build}/${name}.xcarchive" >>"${log}" 2>&1
    exit_code=$?
    if [ $exit_code == 0 ]
    then
        cp "${build}/${name}.xcarchive/Products/usr/local/bin/${name}" "${build}/bin"
        rm -rf "${build}/${name}.xcarchive"
    else
        build_exit_code=1
        echo "FAILED: build_osx_bin ${name}"
    fi
    popd >&/dev/null
}

function release_osx_bin {
    local name=$1

    echo "releasing osx bin ${name}..."

    cp "build/bin/${name}" release/bin
}

build_osx_bin "FireflyFirmwareCrypto"

if [ $build_exit_code == 0 ]
then
    release_osx_bin "FireflyFirmwareCrypto"
else
    echo "FAILED"
fi

exit $build_exit_code
