REPO = https://github.com/bitcoin/secp256k1.git
TAG = v0.4.0

# Sources only: the libsecp256k1 NIF compiles this tree into its own archive.
# Every archive in a NIF's staging dir becomes a static NIF of its own, and the
# NIF includes secp256k1's internal headers anyway, so nothing is built here.
build install clean:
	@:

.PHONY: build install clean
