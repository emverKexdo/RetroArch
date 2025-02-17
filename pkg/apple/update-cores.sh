#!/bin/sh

DEBUG=

if [ -z "$DEBUG" ] ; then
    CURL_DEBUG=-sf
    UNZIP_DEBUG=-q
    NO_RM=
else
    printf "Turning on debug\n"
    CURL_DEBUG=
    UNZIP_DEBUG=
    NO_RM=1
fi

function debug() {
    if [ -n "$DEBUG" ] ; then
        printf "$@\n"
    fi
}

if [ -z "$PROJECT_DIR" ] ; then
    APPLE_DIR=$(dirname $0)
else
    APPLE_DIR="${PROJECT_DIR}/pkg/apple"
fi

if [ "$1" = "tvos" -o "$1" = "--tvos" ] ; then
    CORES_DIR="${APPLE_DIR}/tvOS/modules"
    PLATFORM=tvos
    shift
else
    CORES_DIR="${APPLE_DIR}/iOS/modules"
    PLATFORM=ios
fi
debug CORES_DIR is $CORES_DIR
cd "$CORES_DIR"

URL_BASE="https://buildbot.libretro.com/nightly/apple/${PLATFORM}-arm64/latest"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

function update_dylib() {
    dylib=$1
    printf "Updating ${YELLOW}$dylib${NC}... "
    mv "$dylib" "$dylib".bak
    debug curl $CURL_DEBUG -o "$dylib".zip "$URL_BASE"/"$dylib".zip
    curl $CURL_DEBUG -o "$dylib".zip "$URL_BASE"/"$dylib".zip
    if [ ! -f "$dylib".zip ] ; then
        printf "${RED}Download failed${NC}\n"
        mv "$dylib".bak "$dylib"
    else
        debug unzip $UNZIP_DEBUG "$dylib".zip
        unzip $UNZIP_DEBUG "$dylib".zip
        if [ ! -f "$dylib" ] ; then
            printf "${RED}Unzip failed${NC}\n"
            mv "$dylib".bak "$dylib"
        else
            printf "${GREEN}Success!${NC}\n"
            [ -n "$NO_RM" ] || rm "$dylib".zip "$dylib".bak
        fi
    fi
}

allcores=
function get_all_cores() {
    if [ -z "$allcores"] ; then
        allcores=($(curl $CURL_DEBUG $URL_BASE/ | sed -e 's/></\n/g' | grep '>[^<]\+\.dylib.zip<' | sed -e 's/.*>\(.*\)<.*/\1/'))
    fi
}

if [ -n "$1" ]; then
    dylibs=()
    get_all_cores
    while [ -n "$1" ] ; do
        if [[ "${allcores[*]}" =~ "${1}_libretro_${PLATFORM}.dylib.zip" ]] ; then
            dylibs+=("${1}_libretro_${PLATFORM}.dylib.zip")
        elif [[ "${allcores[*]}" =~ "${1}_libretro.dylib.zip" ]] ; then
            dylibs+=("${1}_libretro.dylib.zip")
        fi
        shift
    done
else
    dylibs=( *_libretro*.dylib )
fi

if [[ -z "${dylibs[*]}" ]] ; then
    echo Available cores:
    for i in "${allcores[@]}" ; do
        echo $i
    done
fi

# TODO: command line arg to indicate which cores to update
for dylib in "${dylibs[@]}" ; do
    update_dylib "$dylib"
done
