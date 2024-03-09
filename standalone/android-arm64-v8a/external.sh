#!/bin/bash

set -e

BGFX_CMAKE_VERSION=1.125.8678-462

SDL2_VERSION=2.30.0
SDL2_IMAGE_VERSION=2.8.2
SDL2_TTF_VERSION=2.22.0

PINMAME_SHA=e867f6e50e12238e0db658ccc9dde6d19a350c12
LIBALTSOUND_SHA=9ac08a76e2aabc1fba57d3e5a3b87e7f63c09e07
LIBDMDUTIL_SHA=c6ab88089ab81b4a5bc676927369351059becde5

if [[ $(uname) == "Linux" ]]; then
   NUM_PROCS=$(nproc)
elif [[ $(uname) == "Darwin" ]]; then
   NUM_PROCS=$(sysctl -n hw.ncpu)
else
   NUM_PROCS=1
fi

echo "Building external libraries..."
echo "  BGFX_CMAKE_VERSION: ${BGFX_CMAKE_VERSION}"
echo "  SDL2_VERSION: ${SDL2_VERSION}"
echo "  SDL2_IMAGE_VERSION: ${SDL2_IMAGE_VERSION}"
echo "  SDL2_TTF_VERSION: ${SDL2_TTF_VERSION}"
echo "  PINMAME_SHA: ${PINMAME_SHA}"
echo "  LIBALTSOUND_SHA: ${LIBALTSOUND_SHA}"
echo "  LIBDMDUTIL_SHA: ${LIBDMDUTIL_SHA}"
echo ""

if [ -z "${BUILD_TYPE}" ]; then
   BUILD_TYPE="Release"
fi

echo "Build type: ${BUILD_TYPE}"
echo "Procs: ${NUM_PROCS}"
echo ""

rm -rf external
mkdir external
mkdir external/include
mkdir external/lib

rm -rf tmp
mkdir tmp
cd tmp

#
# build bgfx and copy to external
#

curl -sL https://github.com/bkaradzic/bgfx.cmake/releases/download/v${BGFX_CMAKE_VERSION}/bgfx.cmake.v${BGFX_CMAKE_VERSION}.tar.gz -o bgfx.cmake.v${BGFX_CMAKE_VERSION}.tar.gz
tar -xvzf bgfx.cmake.v${BGFX_CMAKE_VERSION}.tar.gz
cd bgfx.cmake
cp -r bgfx/include/bgfx ../../external/include
cp -r bimg/include/bimg ../../external/include
cp -r bx/include/bx ../../external/include
cmake -S. \
   -DCMAKE_SYSTEM_NAME=Android \
   -DCMAKE_SYSTEM_VERSION=30 \
   -DCMAKE_ANDROID_ARCH_ABI=arm64-v8a \
   -DBGFX_BUILD_EXAMPLES=OFF \
   -DCMAKE_BUILD_TYPE=Release \
   -B build
cmake --build build -- -j${NUM_PROCS}
cp build/cmake/bgfx/*.a ../../external/lib
cp build/cmake/bimg/*.a ../../external/lib
cp build/cmake/bx/*.a ../../external/lib
cd ..

#
# build freeimage, and copy to external
#

curl -sL https://downloads.sourceforge.net/project/freeimage/Source%20Distribution/3.18.0/FreeImage3180.zip -o FreeImage3180.zip
unzip FreeImage3180.zip
cd FreeImage
cp ../../freeimage/Android.mk Android.mk
cd ..

$ANDROID_NDK_HOME/ndk-build \
   -C FreeImage \
   -j${NUM_PROC} \
   NDK_PROJECT_PATH=$ANDROID_NDK_HOME \
   APP_BUILD_SCRIPT=$(pwd)/FreeImage/Android.mk \
   APP_STL="c++_static" \
   APP_PLATFORM=android-19 \
   APP_ABI=arm64-v8a \
   NDK_OUT=$(pwd)/obj \
   NDK_LIBS_OUT=$(pwd)/libs

cp libs/arm64-v8a/*.so ../external/lib

#
# download bass24 and copy to external
#

curl -sL https://www.un4seen.com/files/bass24-android.zip -o bass.zip
unzip bass.zip 
cp libs/arm64-v8a/libbass.so ../external/lib

#
# build SDL2 and copy to external
# (derived from: https://github.com/AlexanderAgd/SDL2-Android)
#

curl -sL https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.zip -o SDL2-${SDL2_VERSION}.zip
unzip SDL2-${SDL2_VERSION}.zip
cp -r SDL2-${SDL2_VERSION}/include ../external/include/SDL2

$ANDROID_NDK_HOME/ndk-build \
   -C SDL2-${SDL2_VERSION} \
   -j${NUM_PROC} \
   NDK_PROJECT_PATH=$ANDROID_NDK_HOME \
   APP_BUILD_SCRIPT=$(pwd)/SDL2-${SDL2_VERSION}/Android.mk \
   APP_PLATFORM=android-19 \
   APP_ABI=arm64-v8a \
   NDK_OUT=$(pwd)/obj \
   NDK_LIBS_OUT=$(pwd)/libs

cp libs/arm64-v8a/*.so ../external/lib

#
# build SDL2_image and copy to external
# (derived from: https://github.com/AlexanderAgd/SDL2-Android)
#

curl -sL https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL2_IMAGE_VERSION}/SDL2_image-${SDL2_IMAGE_VERSION}.zip -o SDL2_image-${SDL2_IMAGE_VERSION}.zip
unzip SDL2_image-${SDL2_IMAGE_VERSION}.zip
cp SDL2_image-${SDL2_IMAGE_VERSION}/include/SDL_image.h ../external/include/SDL2

MK_ADDON=$'include $(CLEAR_VARS)\\\n'
MK_ADDON+=$'LOCAL_MODULE := SDL2\\\n'
MK_ADDON+=$'LOCAL_SRC_FILES := '"$(pwd)/libs/arm64-v8a"$'/libSDL2.so\\\n'
MK_ADDON+=$'LOCAL_EXPORT_C_INCLUDES += '"$(pwd)/SDL2-${SDL2_VERSION}/include"$'\\\n'
MK_ADDON+="include \$(PREBUILT_SHARED_LIBRARY)"

sed -e $'/(call my-dir)/a\\\n'"$MK_ADDON" SDL2_image-${SDL2_IMAGE_VERSION}/Android.mk > tmp_mk
cp tmp_mk SDL2_image-${SDL2_IMAGE_VERSION}/Android.mk

$ANDROID_NDK_HOME/ndk-build \
   -C SDL2_image-${SDL2_IMAGE_VERSION} \
   -j${NUM_PROC} \
   NDK_PROJECT_PATH=$ANDROID_NDK_HOME \
   APP_BUILD_SCRIPT="$(pwd)/SDL2_image-${SDL2_IMAGE_VERSION}/Android.mk" \
   APP_PLATFORM=android-19 \
   APP_ABI=arm64-v8a \
   APP_ALLOW_MISSING_DEPS=true \
   NDK_OUT=$(pwd)/obj \
   NDK_LIBS_OUT=$(pwd)/libs

cp libs/arm64-v8a/*.so ../external/lib

#
# build SDL2_ttf and copy to external
# (derived from: https://github.com/AlexanderAgd/SDL2-Android)
#

curl -sL https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL2_TTF_VERSION}/SDL2_ttf-${SDL2_TTF_VERSION}.zip -o SDL2_ttf-${SDL2_TTF_VERSION}.zip
unzip SDL2_ttf-${SDL2_TTF_VERSION}.zip
cp -r SDL2_ttf-${SDL2_TTF_VERSION}/SDL_ttf.h ../external/include/SDL2

MK_ADDON=$'include $(CLEAR_VARS)\\\n'
MK_ADDON+=$'LOCAL_MODULE := SDL2\\\n'
MK_ADDON+=$'LOCAL_SRC_FILES := '"$(pwd)/libs/arm64-v8a"$'/libSDL2.so\\\n'
MK_ADDON+=$'LOCAL_EXPORT_C_INCLUDES += '"$(pwd)/SDL2-${SDL2_VERSION}/include"$'\\\n'
MK_ADDON+="include \$(PREBUILT_SHARED_LIBRARY)"

sed -e $'/(call my-dir)/a\\\n'"$MK_ADDON" SDL2_ttf-${SDL2_TTF_VERSION}/Android.mk > tmp_mk
cp tmp_mk SDL2_ttf-${SDL2_TTF_VERSION}/Android.mk

$ANDROID_NDK_HOME/ndk-build \
   -C SDL2_ttf-${SDL2_TTF_VERSION} \
   -j${NUM_PROC} \
   NDK_PROJECT_PATH=$ANDROID_NDK_HOME \
   APP_BUILD_SCRIPT="$(pwd)/SDL2_ttf-${SDL2_TTF_VERSION}/Android.mk" \
   APP_PLATFORM=android-19 \
   APP_ABI=arm64-v8a \
   APP_ALLOW_MISSING_DEPS=true \
   NDK_OUT=$(pwd)/obj \
   NDK_LIBS_OUT=$(pwd)/libs

cp libs/arm64-v8a/*.so ../external/lib

#
# build libpinmame and copy to external
#

curl -sL https://github.com/vpinball/pinmame/archive/${PINMAME_SHA}.zip -o pinmame.zip
unzip pinmame.zip
cd pinmame-$PINMAME_SHA
cp src/libpinmame/libpinmame.h ../../external/include
cp cmake/libpinmame/CMakeLists_android-arm64-v8a.txt CMakeLists.txt
cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -B build
cmake --build build -- -j${NUM_PROCS}
cp build/libpinmame.3.6.so ../../external/lib
cd ..

#
# build libaltsound and copy to external
#

curl -sL https://github.com/vpinball/libaltsound/archive/${LIBALTSOUND_SHA}.zip -o libaltsound.zip
unzip libaltsound.zip
cd libaltsound-$LIBALTSOUND_SHA
cp src/altsound.h ../../external/include
platforms/android/arm64-v8a/external.sh
cmake -DPLATFORM=android -DARCH=arm64-v8a -DBUILD_STATIC=OFF -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -B build
cmake --build build -- -j${NUM_PROCS}
cp build/*.so ../../external/lib
cd ..

#
# build libdmdutil (and deps) and copy to external
#

curl -sL https://github.com/vpinball/libdmdutil/archive/${LIBDMDUTIL_SHA}.zip -o libdmdutil.zip
unzip libdmdutil.zip
cd libdmdutil-$LIBDMDUTIL_SHA
cp -r include/DMDUtil ../../external/include
platforms/android/arm64-v8a/external.sh
cp -r third-party/include/sockpp ../../external/include
cmake -DPLATFORM=android -DARCH=arm64-v8a -DBUILD_STATIC=OFF -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -B build
cmake --build build -- -j${NUM_PROCS}
cp third-party/runtime-libs/android/arm64-v8a/*.so ../../external/lib
cp build/*.so ../../external/lib
cd ..
