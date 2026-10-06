REPO = https://github.com/libgit2/libgit2.git
TAG = v1.9.7

DEPS = openssl

# Cross build: pkg-config must only see the openssl built for this arch, never
# the host's .pc files (whose Libs.private leak host-only libs into the link).
export PKG_CONFIG_LIBDIR = $(BUILD_PATH)/openssl/lib/pkgconfig
export PKG_CONFIG_PATH =

build: build-$(PLATFORM)

# REGEX_BACKEND=regcomp: left unset, the cross build fails the regcomp_l probe
# and falls back to libgit2's bundled PCRE2, whose pcre2_* symbols collide with
# ERTS' own copy (libepcre.a) once linked statically into beam. Bionic's POSIX
# regcomp is enough for libgit2.
build-android:
	cmake -B $(BUILD_PATH)/libgit2 \
		-G Ninja \
		-DCMAKE_TOOLCHAIN_FILE=$(ANDROID_NDK_HOME)/build/cmake/android.toolchain.cmake \
		-DANDROID_ABI=$(ANDROID_ABI) \
		-DANDROID_PLATFORM=android-$(ANDROID_PLATFORM) \
		-DCMAKE_BUILD_TYPE=Release \
		-DBUILD_SHARED_LIBS=OFF \
		-DBUILD_TESTS=OFF \
		-DBUILD_EXAMPLES=OFF \
		-DBUILD_CLI=OFF \
		-DUSE_THREADS=ON \
		-DUSE_SSH=OFF \
		-DREGEX_BACKEND=regcomp \
		-DUSE_HTTPS=OpenSSL \
		-DOPENSSL_ROOT_DIR=$(BUILD_PATH)/openssl \
		-DOPENSSL_USE_STATIC_LIBS=ON \
		-DCMAKE_FIND_ROOT_PATH=$(BUILD_PATH)/openssl
	cmake --build $(BUILD_PATH)/libgit2

install: $(STAGING_PATH)/libgit2/libgit2.a

$(STAGING_PATH)/libgit2/libgit2.a: $(BUILD_PATH)/libgit2/libgit2.a
	mkdir -p $(@D)
	cp $< $@

clean:
	-rm -fr $(BUILD_PATH)/libgit2

.PHONY: build build-android install clean
