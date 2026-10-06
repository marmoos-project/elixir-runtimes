REPO = https://github.com/saleyn/egit.git
TAG = 384977b0cb1371079dafa1b3e6ff2b327d857b75
DEPS = libgit2 libssh2
EXTRA_RUNTIME = c++_static c++abi

nif = git.a

# The NDK's libc++ has std::format and std::source_location; egit's own
# detection doesn't recognise the NDK's clang++ path and would fall back to fmt.
export HAVE_FORMAT = 1
export HAVE_SRCLOC = 1

# egit sets -std=c++20 with `CXXFLAGS ?=`, which the CXXFLAGS from the build env
# overrides.
export CXXFLAGS += -std=c++20

# egit asks the host erl for ERTS headers and pkg-config for libgit2; point both
# at what was built for the target arch instead.
export ERL_CXXFLAGS = -I$(ERTS_INCLUDE_DIR)
export CPPFLAGS += -I$(BUILD_PATH)/libgit2/include -DSTATIC_ERLANG_NIF=1

# egit only knows how to link a shared git.so; the NIF is linked statically into
# ERTS instead, so only its object is built here and archived. HAVE_FMTLIB is
# set on the command line to skip egit's `pkg-config fmt` probe, which is unused
# with HAVE_FORMAT.
obj = $(CURDIR)/c_src/git.o

build: $(BUILD_PATH)/egit/$(nif)

$(BUILD_PATH)/egit/$(nif): $(obj)
	mkdir -p $(@D)
	$(AR) rc $@ $^
	$(RANLIB) $@

$(obj): c_src/*.cpp c_src/*.hpp
	$(MAKE) -C c_src HAVE_FMTLIB=unused $@

install:
	mkdir -p $(STAGING_PATH)/egit
	cp $(BUILD_PATH)/egit/$(nif) $(STAGING_PATH)/egit/$(nif)

clean:
	rm -f $(BUILD_PATH)/egit/$(nif) $(obj)

.PHONY: build install clean
