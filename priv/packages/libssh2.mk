REPO = https://github.com/libssh2/libssh2.git
TAG = libssh2-1.11.1

DEPS = openssl

ANDROID_NDK=$(ANDROID_NDK_HOME)
export ANDROID_NDK

# Cross build: pkg-config must only see the openssl built for this arch, never
# the host's .pc files (whose Libs.private leak host-only libs into the link).
export PKG_CONFIG_LIBDIR = $(BUILD_PATH)/openssl/lib/pkgconfig
export PKG_CONFIG_PATH =

build: build-$(PLATFORM)

build-android:
	cmake \
		-S . \
		-B $(BUILD_PATH)/libssh2 \
		-G Ninja \
		-DCMAKE_TOOLCHAIN_FILE=$(ANDROID_NDK)/build/cmake/android.toolchain.cmake \
		-DANDROID_ABI=$(ANDROID_ABI) \
		-DANDROID_PLATFORM=android-$(ANDROID_PLATFORM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DCRYPTO_BACKEND=OpenSSL \
		-DOPENSSL_ROOT_DIR=$(BUILD_PATH)/openssl \
		-DOPENSSL_USE_STATIC_LIBS=ON \
		-DCMAKE_FIND_ROOT_PATH=$(BUILD_PATH)/openssl \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_STATIC_LIBS=ON \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_TESTING=OFF
	cmake --build $(BUILD_PATH)/libssh2

install: $(STAGING_PATH)/libssh2/libssh2.a

$(STAGING_PATH)/libssh2/libssh2.a: $(BUILD_PATH)/libssh2/src/libssh2.a
	mkdir -p $(@D)
	cp $< $@

clean:
	-rm -fr $(BUILD_PATH)/libssh2

.PHONY: build build-android install clean