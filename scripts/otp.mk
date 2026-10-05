# Run by compile.otp task
REPO = https://github.com/erlang/otp.git
TAG = OTP-29.0.3

otp_build_opts = \
	--with-ssl=$(BUILD_PATH)/openssl \
	--disable-dynamic-ssl-lib \
	--enable-builtin-zlib \
	--disable-year2038 \
	--without-javac --without-odbc --without-wx \
	--without-debugger --without-observer --without-cdv \
	--without-et \
	--xcomp-conf=xcomp/erl-xcomp-$(ARCH_XCOMP).conf \
	--enable-static-nifs=$(NIFS)

all: 

STAMP_PREPARE = $(BUILD_PATH)/.stamp_otp_prepare
prepare: | $(STAMP_PREPARE)

$(STAMP_PREPARE): $(BUILD_PATH)/otp/otp_build
	cd $(BUILD_PATH)/otp && \
		git clean -xdf && \
		./otp_build setup $(otp_build_opts) && \
		./otp_build boot -a && \
		./otp_build release -a && \
	touch $(STAMP_PREPARE)

STAMP_BUILD = $(BUILD_PATH)/.stamp_otp_build
build: | $(STAMP_BUILD)

$(STAMP_BUILD): $(STAMP_PREPARE)
	cd $(BUILD_PATH)/otp && \
		./otp_build configure $(otp_build_opts) && \
		./otp_build boot -a && \
		./otp_build release -a
	touch $(STAMP_BUILD)

$(BUILD_PATH)/otp/otp_build: | $(DEPS_PATH)/otp/otp_build
	@echo "Cloning OTP repository into $(@D)" && \
		git clone $(DEPS_PATH)/otp $(@D)

install:
	mkdir -p $(STAGING_PATH)/otp
	build_host=$$($(BUILD_PATH)/otp/erts/autoconf/config.guess) && \
		find $(BUILD_PATH)/otp -type f -name '*.a' \
			-path "*$(ARCH_NAME)*" \
			! -path "*$$build_host*" \
			! -name '*_st.a' ! -name '*_r.a' \
			-exec cp {} $(STAGING_PATH)/otp/ \;

clean:
	@[ -d $(BUILD_PATH)/otp ] && \
		cd $(BUILD_PATH)/otp && \
		git clean -xdf || true
	@-rm -f $(BUILD_PATH)/.stamp_otp_*

.PHONY: all prepare build clean install
