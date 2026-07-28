#!/usr/bin/env python3
"""Fail when a Mach-O object targets an iOS version above the requested one."""

from __future__ import annotations

import argparse
import collections
import pathlib
import struct
import sys


LC_VERSION_MIN_IPHONEOS = 0x25
LC_BUILD_VERSION = 0x32
MH_MAGIC_64 = 0xFEEDFACF
PLATFORM_IOS = 2


def decode_version(value: int) -> tuple[int, int, int]:
    return value >> 16, (value >> 8) & 0xFF, value & 0xFF


def parse_version(value: str) -> tuple[int, int, int]:
    pieces = value.split(".")
    if not 1 <= len(pieces) <= 3 or any(not piece.isdigit() for piece in pieces):
        raise argparse.ArgumentTypeError(
            f"{value!r} is not a valid major[.minor[.patch]] version"
        )
    return tuple(int(piece) for piece in pieces) + (0,) * (3 - len(pieces))


def format_version(value: tuple[int, int, int]) -> str:
    major, minor, patch = value
    return f"{major}.{minor}.{patch}"


def deployment_targets(path: pathlib.Path) -> list[tuple[int, int, int]]:
    data = path.read_bytes()
    if len(data) < 32 or struct.unpack_from("<I", data)[0] != MH_MAGIC_64:
        return []

    command_count = struct.unpack_from("<I", data, 16)[0]
    command_offset = 32
    targets: list[tuple[int, int, int]] = []
    for _ in range(command_count):
        if command_offset + 8 > len(data):
            raise ValueError("truncated Mach-O load command")
        command, command_size = struct.unpack_from("<II", data, command_offset)
        if command_size < 8 or command_offset + command_size > len(data):
            raise ValueError("invalid Mach-O load command size")

        if command == LC_VERSION_MIN_IPHONEOS and command_size >= 16:
            targets.append(
                decode_version(struct.unpack_from("<I", data, command_offset + 8)[0])
            )
        elif command == LC_BUILD_VERSION and command_size >= 24:
            platform, minimum = struct.unpack_from("<II", data, command_offset + 8)
            if platform == PLATFORM_IOS:
                targets.append(decode_version(minimum))
        command_offset += command_size
    return targets


def object_files(paths: list[pathlib.Path]) -> list[pathlib.Path]:
    result: list[pathlib.Path] = []
    for path in paths:
        if path.is_dir():
            result.extend(candidate for candidate in path.rglob("*.o") if candidate.is_file())
        elif path.is_file():
            result.append(path)
        else:
            raise FileNotFoundError(path)
    return sorted(result)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--maximum",
        required=True,
        type=parse_version,
        help="maximum supported iOS deployment target",
    )
    parser.add_argument("paths", nargs="+", type=pathlib.Path)
    arguments = parser.parse_args()

    files = object_files(arguments.paths)
    if not files:
        print("No object files were found.", file=sys.stderr)
        return 2

    versions: collections.Counter[tuple[int, int, int]] = collections.Counter()
    missing: list[pathlib.Path] = []
    incompatible: list[tuple[pathlib.Path, tuple[int, int, int]]] = []
    malformed: list[tuple[pathlib.Path, str]] = []
    for path in files:
        try:
            targets = deployment_targets(path)
        except (OSError, ValueError, struct.error) as error:
            malformed.append((path, str(error)))
            continue
        if not targets:
            missing.append(path)
            continue
        for target in targets:
            versions[target] += 1
            if target > arguments.maximum:
                incompatible.append((path, target))

    for version, count in sorted(versions.items()):
        print(f"iOS {format_version(version)}: {count} object(s)")

    if malformed:
        for path, message in malformed[:20]:
            print(f"Malformed Mach-O object {path}: {message}", file=sys.stderr)
        return 1
    if missing:
        for path in missing[:20]:
            print(f"Missing iOS deployment metadata: {path}", file=sys.stderr)
        return 1
    if incompatible:
        for path, version in incompatible[:20]:
            print(
                f"{path} requires iOS {format_version(version)}, above "
                f"{format_version(arguments.maximum)}",
                file=sys.stderr,
            )
        return 1

    print(
        f"Verified {len(files)} Mach-O object(s) support iOS "
        f"{format_version(arguments.maximum)} or earlier."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
