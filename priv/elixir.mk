REPO = https://github.com/elixir-lang/elixir.git
TAG = v1.20.2

build_dir = $(BUILD_INDEP_PATH)/elixir
src_proof = lib/elixir/mix.exs
output = $(build_dir)/lib/elixir/ebin/iex.beam

rebar = $(MIX_HOME)/bin/rebar3

all:

build: | $(output)

$(output): $(build_dir)/$(src_proof)
	$(MAKE) -C $(build_dir)

$(build_dir)/$(src_proof): | $(DEPS_PATH)/elixir/$(src_proof)
	@echo "Cloning elixir repository into $(@D)" && \
		git clone $(DEPS_PATH)/elixir $(build_dir)

install:
	mix do local.hex --force
	mix do local.rebar --force

clean:
	@[ -d $(build_dir) ] && \
		cd $(build_dir) && \
		git clean -xdf || true

.PHONY: all build clean