# libarchive

This directory contains a source-only subset of libarchive 3.8.9, used for
native RAR and RAR5 manga archive reading.

- Upstream: https://github.com/libarchive/libarchive
- Release archive: `libarchive-3.8.9.tar.xz`
- SHA-256: `888c934f9d95648ecb9163dc8e23ab80a476ecb81a8f1154704a227b5b676dde`
- License: BSD-2-Clause; see `COPYING`

The upstream source files are unmodified. Documentation, command-line tools,
and test data that are not needed to build the static library have been
omitted. The retained empty test CMake files allow the unmodified upstream
CMake project to configure with tests and tools disabled.

Mangatan's Rust build configures this copy as a static library and disables
all optional external codecs, crypto libraries, XML libraries, ACL/xattr
support, tools, installation rules, and upstream tests. RAR and RAR5 decoding
is implemented inside libarchive and does not require those dependencies.
