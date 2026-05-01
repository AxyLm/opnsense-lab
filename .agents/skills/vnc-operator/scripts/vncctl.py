#!/usr/bin/env python3
"""Small RFB/VNC operator for typing text and taking screenshots."""

import argparse
import binascii
import os
import socket
import struct
import subprocess
import sys
import time
import zlib
from pathlib import Path

SHIFT = 0xFFE1
ENTER = 0xFF0D
BACKSPACE = 0xFF08

SHIFTED = {
    "!": "1",
    "@": "2",
    "#": "3",
    "$": "4",
    "%": "5",
    "^": "6",
    "&": "7",
    "*": "8",
    "(": "9",
    ")": "0",
    "_": "-",
    "+": "=",
    "{": "[",
    "}": "]",
    "|": "\\",
    ":": ";",
    '"': "'",
    "<": ",",
    ">": ".",
    "?": "/",
    "~": "`",
}


def recvn(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise RuntimeError("connection closed")
        data += chunk
    return data


def terraform_output(name):
    script_path = Path(__file__).resolve()
    for parent in script_path.parents:
        tf_dir = parent / "terrform"
        if tf_dir.is_dir() and (parent / "AGENTS.md").is_file():
            result = subprocess.run(
                ["terraform", f"-chdir={tf_dir}", "output", "-raw", name],
                check=False,
                capture_output=True,
                text=True,
            )
            if result.returncode == 0:
                return result.stdout.strip()
    return ""


def default_port():
    env_port = os.environ.get("VNC_PORT")
    if env_port:
        try:
            return int(env_port)
        except ValueError:
            pass

    url = terraform_output("vnc_url")
    if ":" in url:
        try:
            return int(url.rsplit(":", 1)[1])
        except ValueError:
            pass
    return 5902


def connect(host, port):
    sock = socket.create_connection((host, port), timeout=5)
    sock.settimeout(10)
    proto = recvn(sock, 12)
    sock.sendall(proto)
    if proto.decode("ascii", "replace") >= "RFB 003.007":
        count = recvn(sock, 1)[0]
        types = recvn(sock, count)
        if 1 not in types:
            raise RuntimeError(f"NoAuth unavailable: {types!r}")
        sock.sendall(b"\x01")
        result = struct.unpack(">I", recvn(sock, 4))[0]
        if result != 0:
            raise RuntimeError(f"security failed: {result}")
    else:
        sec = struct.unpack(">I", recvn(sock, 4))[0]
        if sec != 1:
            raise RuntimeError(f"NoAuth unavailable: {sec}")
    sock.sendall(b"\x01")
    width, height = struct.unpack(">HH", recvn(sock, 4))
    recvn(sock, 16)
    name_len = struct.unpack(">I", recvn(sock, 4))[0]
    recvn(sock, name_len)
    return sock, width, height


def key(sock, keysym, down):
    sock.sendall(struct.pack(">BBHI", 4, 1 if down else 0, 0, keysym))
    time.sleep(0.012)


def tap(sock, keysym):
    key(sock, keysym, True)
    key(sock, keysym, False)


def type_char(sock, char):
    if char == "\n":
        tap(sock, ENTER)
    elif char == "\b":
        tap(sock, BACKSPACE)
    elif char in SHIFTED:
        key(sock, SHIFT, True)
        tap(sock, ord(SHIFTED[char]))
        key(sock, SHIFT, False)
    elif "A" <= char <= "Z":
        tap(sock, ord(char))
    else:
        tap(sock, ord(char))


def type_text(sock, text, delay):
    for char in text:
        type_char(sock, char)
        time.sleep(delay)


def png_chunk(kind, data):
    return (
        struct.pack(">I", len(data))
        + kind
        + data
        + struct.pack(">I", binascii.crc32(kind + data) & 0xFFFFFFFF)
    )


def screenshot(sock, width, height, out):
    pixfmt = struct.pack(">BBBBHHHBBBxxx", 32, 24, 0, 1, 255, 255, 255, 16, 8, 0)
    sock.sendall(b"\x00\x00\x00\x00" + pixfmt)
    sock.sendall(struct.pack(">BBH", 2, 0, 1) + struct.pack(">i", 0))
    sock.sendall(struct.pack(">BBHHHH", 3, 0, 0, 0, width, height))
    if recvn(sock, 1)[0] != 0:
        raise RuntimeError("unexpected RFB message")
    recvn(sock, 1)
    rects = struct.unpack(">H", recvn(sock, 2))[0]
    rgb = bytearray(width * height * 3)
    for _ in range(rects):
        x, y, rw, rh, encoding = struct.unpack(">HHHHi", recvn(sock, 12))
        if encoding != 0:
            raise RuntimeError(f"unexpected encoding: {encoding}")
        raw = recvn(sock, rw * rh * 4)
        for row in range(rh):
            for col in range(rw):
                b, g, r, _pad = raw[(row * rw + col) * 4 : (row * rw + col) * 4 + 4]
                off = ((y + row) * width + x + col) * 3
                rgb[off : off + 3] = bytes((r, g, b))
    scanlines = b"".join(
        b"\x00" + rgb[row * width * 3 : (row + 1) * width * 3]
        for row in range(height)
    )
    png = (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + png_chunk(b"IDAT", zlib.compress(scanlines, 9))
        + png_chunk(b"IEND", b"")
    )
    Path(out).write_bytes(png)


def main():
    parser = argparse.ArgumentParser(
        description="Operate a NoAuth RFB/VNC endpoint with keyboard input and PNG screenshots."
    )
    parser.add_argument("command", choices=["type", "screenshot"])
    parser.add_argument("value")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=default_port())
    parser.add_argument("--delay", type=float, default=0.01)
    args = parser.parse_args()

    sock, width, height = connect(args.host, args.port)
    with sock:
        if args.command == "type":
            type_text(sock, args.value, args.delay)
        else:
            screenshot(sock, width, height, args.value)


if __name__ == "__main__":
    sys.exit(main())
