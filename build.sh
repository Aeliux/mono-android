#!/bin/bash

# compile mono for PC with .Net Class Libraries
mkdir -p out

export CC=
export CXX=
export LDFLAGS=
./autogen.sh --disable-system-aot
make
make install "DESTDIR=$(realpath out)/bin-PC"

arch=aarch64 # arch can be any of aarch64, armv7a
api_level=24 # api level can be any of 21-24,26-30
# patch for log output (defaults to adb log rather than terminal)
sed -i 's|#if HOST_ANDROID|#if 0|g' mono/eglib/goutput.c
sed -i 's/#if defined(HOST_ANDROID) || !defined(HAVE_ATEXIT)/#if 0/g' mono/utils/mono-proclib.c
if [ "$arch" = "armv7a" ]; then
  sed -i 's|#define USE_TKILL_ON_ANDROID 1||g' mono/metadata/threads.c
  sed -i 's|#define USE_TKILL_ON_ANDROID 1||g' mono/utils/mono-threads-posix.c
fi

if [ "$arch" = "armv7a" ]; then
  target=$arch-linux-androideabi
else
  target=$arch-linux-android
fi

export CC="$(realpath .ndk)/android-ndk-r22/toolchains/llvm/prebuilt/linux-x86_64/bin/clang --target=$target$api_level --sysroot=$(realpath ..)/android-ndk-r22/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
export CXX="$(realpath .ndk)/android-ndk-r22/toolchains/llvm/prebuilt/linux-x86_64/bin/clang --target=$target$api_level --sysroot=$(realpath ..)/android-ndk-r22/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
if [ "$api_level" -ge "24" ]; then
  export LDFLAGS="-lz -Wl,-rpath='\$\$ORIGIN/../lib' -Wl,--enable-new-dtags"
else
  export LDFLAGS="-lz" # see https://github.com/termux/termux-packages/issues/2071
fi
if [ "$arch" = "armv7a" ]; then
  extra_flags=--with-btls-android-ndk-asm-workaround
else
  extra_flags=
fi
./configure --host=$target --prefix=/data/data/com.termux/files/usr/local --disable-mcs-build --with-btls-android-ndk="$(realpath .ndk)/android-ndk-r22" --with-btls-android-api=$api_level --with-btls-android-cmake-toolchain="$(realpath .ndk)/android-ndk-r22/build/cmake/android.toolchain.cmake" $extra_flags
make
make install "DESTDIR=$(realpath out)/bin-android"

# copy .Net Class Libraries
cp -rf out/bin-PC/usr/local/lib/mono out/bin-android/data/data/com.termux/files/usr/local/lib/

# Some libraries may use libc.so.6, which doesn't exist on Android. We can create a symbol link to libc.so.
if [ "$arch" = "armv7a" ]; then
  ln -s /system/lib/libc.so out/bin-android/data/data/com.termux/files/usr/local/lib/libc.so.6
else
  ln -s /system/lib64/libc.so out/bin-android/data/data/com.termux/files/usr/local/lib/libc.so.6
fi

# wget https://download.mono-project.com/repo/ubuntu/pool/main/m/msbuild/msbuild_16.6+xamarinxplat.2021.01.15.16.11-0xamarin1+ubuntu2004b1_all.deb

cp -R .msbuild/usr/* out/bin-android/data/data/com.termux/files/usr/local/

sed -i 's|/usr/bin|/data/data/com.termux/files/usr/local/bin|g' out/bin-android/data/data/com.termux/files/usr/local/bin/msbuild
sed -i 's|/usr/lib|/data/data/com.termux/files/usr/local/lib|g' out/bin-android/data/data/com.termux/files/usr/local/bin/msbuild

pushd out/bin-android/data/data/com.termux/files/usr
tar cfJ mono-termux-arm64-android24.tar.xz local
popd

mv out/bin-android/data/data/com.termux/files/usr/mono-termux-arm64-android24.tar.xz .