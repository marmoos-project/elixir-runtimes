REPO = https://github.com/openssl/openssl.git
TAG = openssl-3.6.4

ANDROID_NDK_ROOT=$(ANDROID_NDK_HOME)
export ANDROID_NDK_ROOT

build: build-$(PLATFORM)

build-android:
	./Configure android-$(ARCH) -D__ANDROID_API__=$(ANDROID_PLATFORM) --prefix=$(BUILD_PATH)/openssl
	$(MAKE) clean depend
	$(MAKE)
	$(MAKE) install_sw install_ssldirs

install: $(STAGING_PATH)/openssl/libcrypto.a $(STAGING_PATH)/openssl/libssl.a

$(STAGING_PATH)/openssl/%.a: $(BUILD_PATH)/openssl/lib/%.a
	mkdir -p $(@D)
	cp $< $@

clean:
	-rm -fr $(BUILD_PATH)/openssl

.PHONY: build build-android install clean