REPO = https://github.com/diodechain/libsecp256k1.git
TAG = 1f5ec38c7c42aeefe54931671af80ecc397e76ea
DEPS = secp256k1

# ERL_NIF_INIT(libsecp256k1, ...): OTP names the static init symbol after the
# archive, so it must be libsecp256k1.a.
nif = libsecp256k1.a

# The NIF's own Makefile clones bitcoin/secp256k1 into c_src at build time and
# runs autotools there. Instead, secp256k1 is fetched as a package and built
# from source together with the NIF, into one archive: secp256k1.c plus its
# precomputed tables is upstream's supported non-autotools build.
#
# $(BUILD_PATH)/libsecp256k1 is the per-arch copy of the sources that this
# makefile runs in, so the objects go in a subdirectory of it: `clean` runs
# right after the copy and would otherwise delete the sources. `install` runs
# from the deps checkout instead, hence the absolute path.
secp = $(DEPS_PATH)/secp256k1
build_dir = $(BUILD_PATH)/libsecp256k1/static
srcs = c_src/libsecp256k1_nif.c $(secp)/src/secp256k1.c \
	$(secp)/src/precomputed_ecmult.c $(secp)/src/precomputed_ecmult_gen.c
objs = $(addprefix $(build_dir)/,$(notdir $(srcs:.c=.o)))

# The NIF includes internal headers (hash_impl.h, ...) and contrib/ sources, so
# it needs the source tree itself on the include path, not just include/.
CFLAGS += -O2 -DSTATIC_ERLANG_NIF=1 -I$(ERTS_INCLUDE_DIR)
CFLAGS += -I$(secp) -I$(secp)/src -I$(secp)/include
CFLAGS += -DENABLE_MODULE_RECOVERY=1

vpath %.c $(sort $(dir $(srcs)))

build: $(build_dir)/$(nif)

$(build_dir)/$(nif): $(objs)
	rm -f $@
	$(AR) rc $@ $^
	$(RANLIB) $@

$(build_dir)/%.o: %.c
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

install:
	mkdir -p $(STAGING_PATH)/libsecp256k1
	cp $(build_dir)/$(nif) $(STAGING_PATH)/libsecp256k1/$(nif)

clean:
	rm -rf $(build_dir)

.PHONY: build install clean
