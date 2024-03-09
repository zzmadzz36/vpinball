#!/bin/bash

set -e

BGFX_CMAKE_VERSION=1.125.8678-462

SDL2_VERSION=2.30.0
SDL2_IMAGE_VERSION=2.8.2
SDL2_TTF_VERSION=2.22.0

PINMAME_SHA=e867f6e50e12238e0db658ccc9dde6d19a350c12
LIBALTSOUND_SHA=9ac08a76e2aabc1fba57d3e5a3b87e7f63c09e07
LIBDMDUTIL_SHA=c6ab88089ab81b4a5bc676927369351059becde5
FFMPEG_SHA=e38092ef9395d7049f871ef4d5411eb410e283e0

NUM_PROCS=$(sysctl -n hw.ncpu)

echo "Building external libraries..."
echo "  BGFX_CMAKE_VERSION: ${BGFX_CMAKE_VERSION}"
echo "  SDL2_VERSION: ${SDL2_VERSION}"
echo "  SDL2_IMAGE_VERSION: ${SDL2_IMAGE_VERSION}"
echo "  SDL2_TTF_VERSION: ${SDL2_TTF_VERSION}"
echo "  PINMAME_SHA: ${PINMAME_SHA}"
echo "  LIBALTSOUND_SHA: ${LIBALTSOUND_SHA}"
echo "  LIBDMDUTIL_SHA: ${LIBDMDUTIL_SHA}"
echo "  FFMPEG_SHA: ${FFMPEG_SHA}"
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
   -DBGFX_LIBRARY_TYPE=SHARED \
   -DBGFX_BUILD_EXAMPLES=OFF \
   -DCMAKE_OSX_ARCHITECTURES=arm64 \
   -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
   -DCMAKE_BUILD_TYPE=Release \
   -B build
cmake --build build -- -j${NUM_PROCS}
cp -a build/cmake/bgfx/libbgfx.dylib ../../external/lib
cd ..

#
# build freeimage and copy to external
#

curl -sL https://downloads.sourceforge.net/project/freeimage/Source%20Distribution/3.18.0/FreeImage3180.zip -o FreeImage3180.zip
#curl -sL https://mirrors.ircam.fr/pub/pkgsrc/distfiles/FreeImage3180.zip -o FreeImage3180.zip
unzip FreeImage3180.zip
cd FreeImage
cp ../../freeimage/Makefile.macos.arm64 .
make -f Makefile.macos.arm64 -j${NUM_PROCS}
cp Dist/libfreeimage-arm64.a ../../external/lib/libfreeimage.a
cd ..

#
# download bass24 and copy to external
#

curl -s https://www.un4seen.com/files/bass24-osx.zip -o bass.zip
unzip bass.zip 
cp libbass.dylib ../external/lib

#
# build SDL2 and copy to external
#

curl -sL https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.zip -o SDL2-${SDL2_VERSION}.zip
unzip SDL2-${SDL2_VERSION}.zip
cp -r SDL2-${SDL2_VERSION}/include ../external/include/SDL2
cd SDL2-${SDL2_VERSION}
cmake -DSDL_SHARED=ON \
   -DSDL_STATIC=OFF \
   -DSDL_TEST=OFF \
   -DCMAKE_OSX_ARCHITECTURES=arm64 \
   -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
   -DCMAKE_BUILD_TYPE=Release \
   -B build
cmake --build build -- -j${NUM_PROCS}
# cmake does not make a symbolic link for libSDL2.dylib
ln -s libSDL2-2.0.0.dylib build/libSDL2.dylib
cp -a build/*.dylib ../../external/lib
cd ..

#
# build SDL2_image and copy to external
#

curl -sL https://github.com/libsdl-org/SDL_image/releases/download/release-${SDL2_IMAGE_VERSION}/SDL2_image-${SDL2_IMAGE_VERSION}.zip -o SDL2_image-${SDL2_IMAGE_VERSION}.zip
unzip SDL2_image-${SDL2_IMAGE_VERSION}.zip
cp SDL2_image-${SDL2_IMAGE_VERSION}/include/SDL_image.h ../external/include/SDL2
cd SDL2_image-${SDL2_IMAGE_VERSION}
touch cmake/FindSDL2.cmake # force cmake to use the SDL2 we just built
cmake -DBUILD_SHARED_LIBS=ON \
   -DSDL2IMAGE_SAMPLES=OFF \
   -DSDL2_INCLUDE_DIR=$(pwd)/../SDL2-${SDL2_VERSION}/include \
   -DSDL2_LIBRARY=$(pwd)/../SDL2-${SDL2_VERSION}/build/libSDL2.dylib \
   -DCMAKE_OSX_ARCHITECTURES=arm64 \
   -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
   -DCMAKE_BUILD_TYPE=Release \
   -B build
cmake --build build -- -j${NUM_PROCS}
cp -a build/*.dylib ../../external/lib
cd ..

#
# build SDL2_ttf and copy to external
#

curl -sL https://github.com/libsdl-org/SDL_ttf/releases/download/release-${SDL2_TTF_VERSION}/SDL2_ttf-${SDL2_TTF_VERSION}.zip -o SDL2_ttf-${SDL2_TTF_VERSION}.zip
unzip SDL2_ttf-${SDL2_TTF_VERSION}.zip
cp -r SDL2_ttf-${SDL2_TTF_VERSION}/SDL_ttf.h ../external/include/SDL2
cd SDL2_ttf-${SDL2_TTF_VERSION}
touch cmake/FindSDL2.cmake # force cmake to use the SDL2 we just built
cmake -DBUILD_SHARED_LIBS=ON \
   -DSDL2TTF_SAMPLES=OFF \
   -DSDL2_INCLUDE_DIR=$(pwd)/../SDL2-${SDL2_VERSION}/include \
   -DSDL2_LIBRARY=$(pwd)/../SDL2-${SDL2_VERSION}/build/libSDL2.dylib \
   -DSDL2TTF_VENDORED=ON \
   -DSDL2TTF_HARFBUZZ=ON \
   -DCMAKE_OSX_ARCHITECTURES=arm64 \
   -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 \
   -DCMAKE_BUILD_TYPE=Release \
   -B build
cmake --build build -- -j${NUM_PROCS}
cp -a build/*.dylib ../../external/lib
cd ..

#
# build libpinmame and copy to external
#

curl -sL https://github.com/vpinball/pinmame/archive/${PINMAME_SHA}.zip -o pinmame.zip
unzip pinmame.zip
cd pinmame-$PINMAME_SHA
cp src/libpinmame/libpinmame.h ../../external/include
cp cmake/libpinmame/CMakeLists_osx-arm64.txt CMakeLists.txt
cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DBUILD_STATIC=OFF -B build
cmake --build build -- -j${NUM_PROCS}
cp build/libpinmame.3.6.dylib ../../external/lib
cd ..

#
# build libaltsound and copy to external
#

curl -sL https://github.com/vpinball/libaltsound/archive/${LIBALTSOUND_SHA}.zip -o libaltsound.zip
unzip libaltsound.zip
cd libaltsound-$LIBALTSOUND_SHA
cp src/altsound.h ../../external/include
platforms/macos/arm64/external.sh
cmake -DPLATFORM=macos -DARCH=arm64 -DBUILD_STATIC=OFF -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -B build
cmake --build build -- -j${NUM_PROCS}
cp -a build/*.dylib ../../external/lib
cd ..

#
# build libdmdutil (and deps) and copy to external
#

curl -sL https://github.com/vpinball/libdmdutil/archive/${LIBDMDUTIL_SHA}.zip -o libdmdutil.zip
unzip libdmdutil.zip
cd libdmdutil-$LIBDMDUTIL_SHA
cp -r include/DMDUtil ../../external/include
platforms/macos/arm64/external.sh
cp -r third-party/include/sockpp ../../external/include
cmake -DPLATFORM=macos -DARCH=arm64 -DBUILD_STATIC=OFF -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -B build
cmake --build build -- -j${NUM_PROCS}
cp -a third-party/runtime-libs/macos/arm64/*.dylib ../../external/lib
cp -a build/*.dylib ../../external/lib
cd ..

#
# build FFMPEG libraries and copy to external
#

curl -sL https://github.com/FFmpeg/FFmpeg/archive/${FFMPEG_SHA}.zip -o ffmpeg.zip
unzip ffmpeg.zip
cd ffmpeg-$FFMPEG_SHA
mkdir -p ../../external/include/lib{avcodec,avdevice,avformat,avutil,swresample,swscale}
for lib in libavcodec libavdevice libavformat libavutil libswresample libswscale; do
   cp $lib/*.h ../../external/include/$lib
done
./configure --enable-cross-compile \
   --enable-shared \
   --disable-static \
   --disable-programs \
   --disable-doc \
   --enable-rpath \
   --prefix=. \
   --libdir=@rpath \
   --arch=arm64 \
   --cc='clang -arch arm64' \
   --extra-ldflags='-Wl,-ld_classic'
make -j${NUM_PROCS}
for lib in libavcodec libavdevice libavformat libavutil libswresample libswscale; do
   cp -a $lib/*.dylib ../../external/lib
done
cd ..