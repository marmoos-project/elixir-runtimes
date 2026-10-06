REPO = https://github.com/mmzeeman/esqlite
TAG = 0.8.8

nif = esqlite3_nif.a

# Upstream only builds a shared NIF, through rebar3's port compiler. The same
# sources and defines (rebar.config.script, bundled-sqlite case) are compiled
# here and archived for static linking into ERTS.
#
# $(BUILD_PATH)/esqlite is the per-arch copy of the sources that this makefile
# runs in, so the objects go in a subdirectory of it: `clean` runs right after
# the copy and would otherwise delete the sources. `install` runs from the deps
# checkout instead, hence the absolute path.
build_dir = $(BUILD_PATH)/esqlite/static
srcs = c_src/esqlite3_nif.c c_src/sqlite3/sqlite3.c
objs = $(addprefix $(build_dir)/,$(notdir $(srcs:.c=.o)))

CFLAGS += -DNDEBUG=1 -Os -DSTATIC_ERLANG_NIF=1 -I$(ERTS_INCLUDE_DIR) -Ic_src/sqlite3
CFLAGS += -DSQLITE_DQS=0 -DSQLITE_THREADSAFE=1 -DSQLITE_DEFAULT_MEMSTATUS=0 \
	-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 -DSQLITE_LIKE_DOESNT_MATCH_BLOBS \
	-DSQLITE_MAX_EXPR_DEPTH=0 -DSQLITE_OMIT_DEPRECATED -DSQLITE_OMIT_PROGRESS_CALLBACK \
	-DSQLITE_USE_ALLOCA -DSQLITE_OMIT_AUTOINIT -DSQLITE_USE_URI \
	-DSQLITE_ENABLE_FTS3 -DSQLITE_ENABLE_FTS3_PARENTHESIS -DSQLITE_ENABLE_FTS4 \
	-DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_MATH_FUNCTIONS -DSQLITE_ENABLE_JSON1 \
	-DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_GEOPOLY

vpath %.c $(sort $(dir $(srcs)))

build: $(build_dir)/$(nif)

$(build_dir)/$(nif): $(objs)
	rm -f $@
	$(AR) rc $@ $^
	$(RANLIB) $@

$(build_dir)/%.o: %.c c_src/sqlite3/sqlite3.h
	mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

install:
	mkdir -p $(STAGING_PATH)/esqlite
	cp $(build_dir)/$(nif) $(STAGING_PATH)/esqlite/$(nif)

clean:
	rm -rf $(build_dir)

.PHONY: build install clean
