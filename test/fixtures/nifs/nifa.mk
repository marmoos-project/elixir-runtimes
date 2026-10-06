REPO = https://example.com/nifa.git
DEPS = libb
PLATFORMS = android
EXTRA_RUNTIME = c++_static

build install clean:
	@true

.PHONY: build install clean
