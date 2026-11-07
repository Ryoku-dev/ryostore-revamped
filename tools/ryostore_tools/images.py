from __future__ import annotations

from pathlib import Path
import struct


PREVIEW_SIZE = (1920, 1080)


def webp_dimensions(path: Path) -> tuple[int, int]:
    size = path.stat().st_size
    with path.open("rb") as source:
        header = source.read(12)
        if len(header) != 12 or header[:4] != b"RIFF" or header[8:] != b"WEBP":
            raise ValueError("missing RIFF/WEBP header")
        if struct.unpack("<I", header[4:8])[0] != size - 8:
            raise ValueError("RIFF size does not match the file")
        while source.tell() < size:
            chunk_header = source.read(8)
            if len(chunk_header) != 8:
                raise ValueError("truncated chunk header")
            kind = chunk_header[:4]
            chunk_size = struct.unpack("<I", chunk_header[4:])[0]
            payload_start = source.tell()
            if chunk_size > size - payload_start:
                raise ValueError("chunk extends past the file")
            if kind == b"VP8X":
                payload = source.read(min(chunk_size, 10))
                if chunk_size < 10 or len(payload) < 10:
                    raise ValueError("truncated VP8X header")
                return 1 + int.from_bytes(payload[4:7], "little"), 1 + int.from_bytes(payload[7:10], "little")
            if kind == b"VP8 ":
                payload = source.read(min(chunk_size, 10))
                if chunk_size < 10 or len(payload) < 10 or payload[3:6] != b"\x9d\x01\x2a":
                    raise ValueError("invalid VP8 frame header")
                return int.from_bytes(payload[6:8], "little") & 0x3FFF, int.from_bytes(payload[8:10], "little") & 0x3FFF
            if kind == b"VP8L":
                payload = source.read(min(chunk_size, 5))
                if chunk_size < 5 or len(payload) < 5 or payload[0] != 0x2F:
                    raise ValueError("invalid VP8L frame header")
                bits = int.from_bytes(payload[1:5], "little")
                return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
            source.seek(payload_start + chunk_size + (chunk_size & 1))
    raise ValueError("missing VP8, VP8L or VP8X image chunk")


def preview_problem(path: Path) -> str | None:
    try:
        width, height = webp_dimensions(path)
    except (OSError, ValueError) as error:
        return f"preview must be a WebP image: {error}"
    if (width, height) != PREVIEW_SIZE:
        return f"preview must be {PREVIEW_SIZE[0]}x{PREVIEW_SIZE[1]}, got {width}x{height}"
    return None
