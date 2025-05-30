# -------------------- VALUES TO CONFIGURE --------------------

# Path to Android SDK
SDK_PATH := /Users/dienbui/Library/Android/sdk

# Path to Android NDK
# NDK version must match ndkVersion in app/build.gradle.kts
NDK_PATH  := /Users/dienbui/Library/Android/sdk/ndk/$(shell sed -n '/ndkVersion/p' /Users/dienbui/workspace/baresip-studio/app/build.gradle.kts | sed 's/[^0-9.]*//g')

# Android API level
API_LEVEL := 28

# Set default from following values: [armeabi-v7a, arm64-v8a, x86_64]
ANDROID_TARGET_ARCH := arm64-v8a

# Directory where libraries and include files are installed
OUTPUT_DIR := /Users/dienbui/workspace/baresip-studio/libbaresip-android/distribution.video

# -------------------- GENERATED VALUES --------------------
# if macos, use sysctl -n hw.logicalcpu else use nproc
CPU_COUNT	:= $(shell if [ "$(shell uname -s)" = "Darwin" ]; then sysctl -n hw.logicalcpu; else nproc; fi)
PWD		:= $(shell pwd)

ifeq ($(ANDROID_TARGET_ARCH), armeabi-v7a)
	TARGET       := arm-linux-androideabi
	CLANG_TARGET := armv7a-linux-androideabi
	ARCH         := arm
	OPENSSL_ARCH := android-arm
	MARCH        := armv7-a
	VPX_ARCH     := armv7-android-gcc
else
ifeq ($(ANDROID_TARGET_ARCH), arm64-v8a)
	TARGET       := aarch64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := arm
	OPENSSL_ARCH := android-arm64
	MARCH        := armv8-a
	VPX_ARCH     := arm64-android-gcc
else
ifeq ($(ANDROID_TARGET_ARCH), x86_64)
	TARGET       := x86_64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := x86
	OPENSSL_ARCH := android-x86_64
	MARCH        := x86-64
	VPX_ARCH     := x86_64-android-gcc
else
	exit 1
endif
endif
endif

PLATFORM	:= android-$(API_LEVEL)

OS		:= $(shell uname -s | tr "[A-Z]" "[a-z]")
ifeq ($(OS),linux)
	HOST_OS   := linux-x86_64
endif
ifeq ($(OS),darwin)
	HOST_OS   := darwin-x86_64
endif

# Toolchain and sysroot
TOOLCHAIN	:= $(NDK_PATH)/toolchains/llvm/prebuilt/$(HOST_OS)
CMAKE_TOOLCHAIN_FILE	:= $(NDK_PATH)/build/cmake/android.toolchain.cmake
SYSROOT		:= $(TOOLCHAIN)/sysroot
PKG_CONFIG_LIBDIR	:= $(NDK_PATH)/prebuilt/$(HOST_OS)/lib/pkgconfig

# Toolchain tools
# if macos, use /opt/homebrew/bin
ifeq ($(OS),darwin)
	PATH	:= $(TOOLCHAIN)/bin:/opt/homebrew/bin:/usr/bin:/bin
else
	PATH	:= $(TOOLCHAIN)/bin:/usr/bin:/bin
endif
AR	:= llvm-ar
AS	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CC	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CXX	:= $(CLANG_TARGET)$(API_LEVEL)-clang++
LD	:= ld.lld
RANLIB	:= llvm-ranlib
STRIP	:= llvm-strip

# Compiler and Linker Flags for re and baresip
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT)/usr/include -fPIE -fPIC -march=$(MARCH)

LFLAGS := -fPIE -pie

COMMON_FLAGS := \
	EXTRA_CFLAGS="$(COMMON_CFLAGS) -DANDROID" \
	EXTRA_CXXFLAGS="$(COMMON_CFLAGS) -DANDROID -DHAVE_PTHREAD" \
	EXTRA_LFLAGS="$(LFLAGS)" \
	SYSROOT=$(SYSROOT)/usr \
	HAVE_INTTYPES_H=1 \
	HAVE_GETOPT=1 \
	HAVE_LIBRESOLV= \
	HAVE_RESOLV= \
	HAVE_PTHREAD=1 \
	HAVE_PTHREAD_RWLOCK=1 \
	HAVE_LIBPTHREAD= \
	HAVE_INET_PTON=1 \
	HAVE_INET6=1 \
	HAVE_GETIFADDRS= \
	PEDANTIC= \
	OS=$(OS) \
	ARCH=$(ARCH) \
	USE_OPENSSL=yes \
	USE_OPENSSL_DTLS=yes \
	USE_OPENSSL_SRTP=yes

CMAKE_ANDROID_FLAGS := \
	-DANDROID=ON \
	-DANDROID_PLATFORM=$(API_LEVEL) \
	-DCMAKE_SYSTEM_NAME=Android \
	-DCMAKE_SYSTEM_VERSION=$(API_LEVEL) \
	-DCMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN_FILE) \
	-DANDROID_ABI=$(ANDROID_TARGET_ARCH) \
	-DCMAKE_ANDROID_ARCH_ABI=$(ANDROID_TARGET_ARCH) \
	-DCMAKE_SKIP_INSTALL_RPATH=ON \
	-DCMAKE_C_COMPILER=$(CC) \
	-DCMAKE_CXX_COMPILER=$(CXX) \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DCMAKE_BUILD_TYPE=Release

MODULES := "augain;aaudio;dtls_srtp;g711;stun;turn;ice;presence;mwi;account;natpmp;srtp;uuid;sndfile;debug_cmd;vp8;vp9;snapshot"

default: all
.PHONY: openssl
openssl:
	-make distclean -C openssl
	cd openssl && \
	ANDROID_NDK_ROOT=$(NDK_PATH) PATH=$(PATH) ./Configure $(OPENSSL_ARCH) \
	-U__ANDROID_API__ -D__ANDROID_API__=$(API_LEVEL) \
	no-apps no-asm no-docs no-engine no-gost no-legacy no-shared no-ssl no-tests no-zlib --prefix=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH) && \
	make -j$(CPU_COUNT) && \
	make install

.PHONY: vpx
vpx:
	cd libvpx && \
	CC=$(CLANG_TARGET)$(API_LEVEL)-clang \
	CXX=$(CLANG_TARGET)$(API_LEVEL)-clang++ \
	./configure --target=$(VPX_ARCH) \
		--disable-examples \
		--disable-docs \
		--enable-realtime-only \
		--disable-install-bins \
		--disable-tools \
		--enable-webm-io \
		--enable-libyuv \
		--disable-unit-tests \
		--enable-runtime-cpu-detect \
		--disable-mmx \
		--disable-sse2 \
		--disable-sse3 \
		--disable-ssse3 \
		--disable-sse4_1 \
		--disable-avx \
		--disable-avx2 \
		--disable-avx512 \
		--enable-pic \
		--prefix="$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)"
	cd libvpx && \
	make -j$(CPU_COUNT)
	cd libvpx && \
	make install

libre.a: Makefile
	cd re && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/lib/cmake" \
		-DCMAKE_INSTALL_PREFIX=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH) \
		-DOPENSSL_INCLUDE_DIR=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/include \
		-DLIBRE_BUILD_STATIC=ON \
		-DLIBRE_BUILD_SHARED=OFF \
		-DUSE_OPENSSL=ON \
		-DOPENSSL_USE_STATIC_LIBS=ON \
		-DOPENSSL_CRYPTO_LIBRARY=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/lib/libcrypto.a \
		-DOPENSSL_SSL_LIBRARY=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/lib/libssl.a \
		 && \
	cmake --build . --target re -j$(CPU_COUNT) && \
	cmake --install .

libbaresip: Makefile
	cd baresip && \
	rm -rf build && rm -rf .cache && mkdir build && \
	cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(PWD)/openssl" \
		-DSTATIC=ON \
		-DCMAKE_INSTALL_PREFIX=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH) \
		-DCMAKE_INSTALL_LIBDIR=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/lib \
		-DVPX_INCLUDE_DIR=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/include \
		-DVPX_LIBRARY=$(OUTPUT_DIR)/$(ANDROID_TARGET_ARCH)/lib/libvpx.a \
		-DAAUDIO_INCLUDE_DIR=${TOOLCHAIN}/sysroot/usr/include \
		-DAAUDIO_LIBRARY=${TOOLCHAIN}/sysroot/usr/lib/$(TARGET)/$(API_LEVEL)/libaaudio.so \
		-Dre_DIR=$(PWD)/re/cmake \
		-DRE_LIBRARY=$(PWD)/re/build/libre.a \
		-DRE_INCLUDE_DIR=$(PWD)/re/include \
		-DOPENSSL_ROOT_DIR=$(PWD)/openssl \
		-DCMAKE_C_COMPILER="clang" \
		-DCMAKE_CXX_COMPILER="clang++" \
		-DMODULES=$(MODULES) \
		-DBUILD_BARESIP_EXE=OFF && \
	cmake --build . --target baresip -j$(CPU_COUNT) && \
	cmake --install .

all:
	make libbaresip ANDROID_TARGET_ARCH=arm64-v8a
	make libbaresip ANDROID_TARGET_ARCH=armeabi-v7a

debug:	all
	make libbaresip ANDROID_TARGET_ARCH=x86_64

.PHONY: download-sources
download-sources:
	rm -fr abseil-cpp amr baresip bcg729 codec2 g7221 openssl opus* \
		re sndfile spandsp tiff vo-amrwbenc webrtc zrtpcpp \
		png ffmpeg-android-maker libvpx
	git clone https://github.com/abseil/abseil-cpp.git -b lts_2024_01_16 --single-branch
	git clone https://git.code.sf.net/p/opencore-amr/code -b v0.1.6 --single-branch amr
	git clone https://github.com/baresip/baresip.git
	git clone https://github.com/BelledonneCommunications/bcg729.git -b release/1.1.1 --single-branch
	git clone https://github.com/drowe67/codec2.git -b 1.2.0 --single-branch
	git clone https://github.com/juha-h/libg7221.git -b master --single-branch g7221
	git clone https://github.com/openssl/openssl.git -b openssl-3.5 --single-branch openssl
	git clone https://github.com/xiph/opus.git -b v1.4 --single-branch
	git clone https://github.com/baresip/re.git
	git clone https://github.com/juha-h/libsndfile.git -b master --single-branch sndfile
	git clone https://github.com/juha-h/spandsp.git -b 1.0 --single-branch spandsp
	git clone https://gitlab.com/libtiff/libtiff.git -b v4.7.0 --single-branch tiff
	git clone https://github.com/juha-h/libwebrtc.git -b mobile --single-branch webrtc
	git clone https://git.code.sf.net/p/opencore-amr/vo-amrwbenc --single-branch vo-amrwbenc
	cp -r abseil-cpp/absl webrtc/jni/src/webrtc
	git clone https://github.com/juha-h/ZRTPCPP.git -b master --single-branch zrtpcpp
	git clone https://github.com/pnggroup/libpng.git -b v1.6.48 --single-branch png
	git clone https://github.com/Javernaut/ffmpeg-android-maker.git -b master --single-branch
	git clone https://chromium.googlesource.com/webm/libvpx.git -b v1.15.1 --single-branch libvpx
	patch -d re -p1 < re-patch
	patch -d tiff -p1 < tiff-patch
	patch -d ffmpeg-android-maker -p1 < ffmpeg-android-maker.patch

clean:
	cd libvpx && make distclean && make clean
	make distclean -C baresip
	-make distclean -C openssl
	make distclean -C re
