#!/usr/bin/env python3
"""Check that an iOS executable does not eagerly link a large native runtime."""

from __future__ import annotations

import argparse
import pathlib
import struct
import sys


LC_SEGMENT_64 = 0x19
MH_MAGIC_64 = 0xFEEDFACF


def initializer_count(path: pathlib.Path) -> int:
    data = path.read_bytes()
    if len(data) < 32 or struct.unpack_from("<I", data)[0] != MH_MAGIC_64:
        raise ValueError("not a supported 64-bit Mach-O file")

    command_count = struct.unpack_from("<I", data, 16)[0]
    command_offset = 32
    total = 0
    for _ in range(command_count):
        if command_offset + 8 > len(data):
            raise ValueError("truncated Mach-O load command")
        command, command_size = struct.unpack_from("<II", data, command_offset)
        if command_size < 8 or command_offset + command_size > len(data):
            raise ValueError("invalid Mach-O load command size")
        if command == LC_SEGMENT_64:
            section_count = struct.unpack_from("<I", data, command_offset + 64)[0]
            section_offset = command_offset + 72
            for _ in range(section_count):
                if section_offset + 80 > command_offset + command_size:
                    raise ValueError("truncated Mach-O section")
                section_name = data[section_offset : section_offset + 16]
                section_name = section_name.split(b"\0", 1)[0]
                section_size = struct.unpack_from("<Q", data, section_offset + 40)[0]
                if section_name == b"__mod_init_func":
                    if section_size % 8:
                        raise ValueError("invalid initializer section size")
                    total += section_size // 8
                section_offset += 80
        command_offset += command_size
    return total


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--maximum", type=int, required=True)
    parser.add_argument("path", type=pathlib.Path)
    arguments = parser.parse_args()
    try:
        count = initializer_count(arguments.path)
    except (OSError, ValueError, struct.error) as error:
        print(f"{arguments.path}: {error}", file=sys.stderr)
        return 2
    print(f"{arguments.path}: {count} pre-main initializer(s)")
    if count > arguments.maximum:
        print(
            f"Expected at most {arguments.maximum}; the app is eagerly linking "
            "a native runtime.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
