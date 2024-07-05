#!/bin/bash

if [ "s$1" != "s" ]
then
	FILE_PATH=$(realpath "$1")
fi

PC_PATH=$(realpath .mono-pc)
ANDROID_PATH=$(realpath mono-android)

MSBUILD_PATH=$(realpath .msbuild)
CP_MSBUILD=0

arch=aarch64 # arch can be any of aarch64, armv7a
api_level=24 # api level can be any of 21-24,26-30

if [ -d "$MSBUILD_PATH" ]
then
	echo msbuild found
	CP_MSBUILD=1
fi

if [ -d ndk ]
then
	echo using local ndk
	ANDROID_NDK_ROOT=$(realpath ndk)
elif [ ! -d "$ANDROID_NDK_ROOT" ]
then
	echo cannot find ndk
	exit 1
fi

if [ ! -f "$ANDROID_PATH/.hash" ]
then
	if [ "$FILE_PATH" == "" ]
	then
		echo you must pass the source tar as argument
		exit 1
	fi
	echo prepairing for android build
	if [ -d "$ANDROID_PATH" ]
	then
		rm -rf "$ANDROID_PATH"
	fi
	
	mkdir "$ANDROID_PATH"
	tar -xf "$FILE_PATH" -C "$ANDROID_PATH" --strip-components=1 || exit 1
	sha256sum -b "$FILE_PATH" | cut -d " " -f 1 > "$ANDROID_PATH/.hash"
fi
	
FILE_HASH=$(cat "$ANDROID_PATH/.hash")

if [ "s$_MONO_CONFIG" != "s" ]
then
	FILE_HASH=$(echo $FILE_HASH + $_MONO_CONFIG | sha256sum)
fi

LIB_PATH=$(realpath .libs)/$FILE_HASH

if [ ! -d "$LIB_PATH" ] && [ ! -f "$ANDROID_PATH/.has_mods" ]
then
	if [ "$FILE_PATH" == "" ]
	then
		echo you must pass the source tar as argument
		exit 1
	fi
	
	if [ "s$_MONO_CONFIG" != "s" ]
	then
		echo using custom configuration for .net libraries
	fi
	
	echo prepairing to build .net libraries
	if [ -d "$PC_PATH" ]
	then
		rm -rf "$PC_PATH"
	fi
	
	mkdir "$PC_PATH"
	tar -xf "$FILE_PATH" -C "$PC_PATH" --strip-components=1 || exit 1
	
	# compile mono for PC with .Net Class Libraries
	pushd "$PC_PATH"
	mkdir -p out

	export CC=
	export CXX=
	export LDFLAGS=
	./configure --enable-silent-rules --disable-system-aot $_MONO_CONFIG || exit 1
	
	if [ "s$_MONO_CONFIG" != "s" ]
	then
		echo check the configuration output for .net libraries build, press ctrl+c in 30 sec to cancel
		sleep 30
	fi
	
	make
	make install "DESTDIR=$(realpath out)" || exit 1
	popd
	
	mkdir -p "$LIB_PATH"
	cp -rf "$PC_PATH/out/usr/local/lib/mono" "$LIB_PATH" || exit 1
	rm -rf "$PC_PATH"
else
	echo .net libraries already built
fi

# build mono android
pushd "$ANDROID_PATH"
mkdir -p out

if [ "$arch" = "armv7a" ]; then
  target=$arch-linux-androideabi
else
  target=$arch-linux-android
fi

export CC="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/clang --target=$target$api_level --sysroot=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
export CXX="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/clang --target=$target$api_level --sysroot=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
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

if [ "s$_MONO_CONFIG" != "s" ]
then
	if [ -f .has_initialized ]
	then
		rm .has_initialized
	fi
	
	echo using custom configuration for android build
	sleep 1
fi

if [ ! -f .has_initialized ]
then
	# patch for log output (defaults to adb log rather than terminal)
	sed -i 's|#if HOST_ANDROID|#if 0|g' mono/eglib/goutput.c
	sed -i 's/#if defined(HOST_ANDROID) || !defined(HAVE_ATEXIT)/#if 0/g' mono/utils/mono-proclib.c
	if [ "$arch" = "armv7a" ]; then
	  sed -i 's|#define USE_TKILL_ON_ANDROID 1||g' mono/metadata/threads.c
	  sed -i 's|#define USE_TKILL_ON_ANDROID 1||g' mono/utils/mono-threads-posix.c
	fi
	./configure --enable-silent-rules --host=$target --prefix=/data/data/com.termux/files/usr/local --disable-mcs-build --with-btls-android-ndk="$ANDROID_NDK_ROOT" --with-btls-android-api=$api_level --with-btls-android-cmake-toolchain="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" $extra_flags $_MONO_CONFIG || exit 1
	
	if [ "s$_MONO_CONFIG" != "s" ]
	then
		echo check the configuration output for android build, press ctrl+c in 30 sec to cancel
		sleep 30
	fi
	
	touch .has_initialized
fi

make || exit 1
make install "DESTDIR=$(realpath out)" || exit 1

if [ ! -f .has_mods ]
then
	# copy .Net Class Libraries
	cp -rf "$LIB_PATH"/* out/data/data/com.termux/files/usr/local/lib/ || exit 1
	touch .has_mods
fi

# Some libraries may use libc.so.6, which doesn't exist on Android. We can create a symbol link to libc.so.
if [ ! -L out/data/data/com.termux/files/usr/local/lib/libc.so.6 ]
then
	if [ "$arch" = "armv7a" ]; then
	  ln -s /system/lib/libc.so out/data/data/com.termux/files/usr/local/lib/libc.so.6
	else
	  ln -s /system/lib64/libc.so out/data/data/com.termux/files/usr/local/lib/libc.so.6
	fi
fi

# Copy msbuild files
if [ $CP_MSBUILD == 1 ] && [ ! -f .has_msbuild ]
then
	echo copying msbuild files
	cp -R "$MSBUILD_PATH"/usr/* out/data/data/com.termux/files/usr/local/ || exit 1

	sed -i 's|/usr/bin|/data/data/com.termux/files/usr/local/bin|g' out/data/data/com.termux/files/usr/local/bin/msbuild
	sed -i 's|/usr/lib|/data/data/com.termux/files/usr/local/lib|g' out/data/data/com.termux/files/usr/local/bin/msbuild
	touch .has_msbuild
fi

pushd out/data/data/com.termux/files/usr
tname=mono-termux-$arch-android$api_level\_$(date +%d-%m-%y_%H-%M-%S).tar.xz
echo compressing into $tname
tar cfJ $tname local || exit 1
popd

mv out/data/data/com.termux/files/usr/$tname ..
popd
