REPO = https://github.com/diodechain/esqlite
TAG = a4289840d12bd48d6bbdbb522e6330fb97824fe7

nif = esqlite3_nif.a

# esqlite's own static build (`make all` with STATIC_ERLANG_NIF) puts its objects
# and archive in-tree, so every arch would reuse whichever objects exist. Same
# sources and flags, built per arch instead.
build_dir = $(BUILD_PATH)/esqlite
srcs = c_src/esqlite3_nif.c c_src/queue.c c_src/sqlite3/sqlite3.c
objs = $(addprefix $(build_dir)/,$(notdir $(srcs:.c=.o)))

CFLAGS += -DNDEBUG=1 -Os -DSTATIC_ERLANG_NIF=1 -I$(ERTS_INCLUDE_DIR)
CFLAGS += -DSQLITE_THREADSAFE=1 -DSQLITE_USE_URI -DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS

vpath %.c $(sort $(dir $(srcs)))

build: $(build_dir)/$(nif)

$(build_dir)/$(nif): $(objs)
	rm -f $@
	$(AR) rc $@ $^
	$(RANLIB) $@

$(build_dir)/%.o: %.c c_src/queue.h c_src/sqlite3/sqlite3.h
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

install:
	mkdir -p $(STAGING_PATH)/esqlite
	cp $(build_dir)/$(nif) $(STAGING_PATH)/esqlite/$(nif)

clean:
	rm -rf $(build_dir)

.PHONY: build install clean
