#!/usr/bin/env python3
"""Firmware upload web server for RGB30.

The browser uploads a firmware file, and this server atomically stores it as
/storage/firmware.bin so the Godot OTA page can load it.
"""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote
import hashlib
import json
import os
import re
import time


HOST = "0.0.0.0"
PORT = 8080
TARGET = Path("/storage/firmware.bin")
TMP_TARGET = Path("/storage/firmware.bin.tmp")
LAST_UPLOAD = Path("/tmp/agv_firmware_upload.last")


def html_page(message=""):
    msg = f"<p class='msg'>{message}</p>" if message else ""
    return f"""<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>RGB30 Firmware Upload</title>
  <style>
    body {{
      margin: 0;
      min-height: 100vh;
      background: #04080e;
      color: #eaf7fc;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      display: grid;
      place-items: center;
    }}
    main {{
      width: min(92vw, 620px);
      border: 1px solid #2a5c6e;
      background: #0d1d2b;
      padding: 28px;
    }}
    h1 {{ margin: 0 0 10px; font-size: 24px; }}
    p {{ color: #b2d6e0; line-height: 1.55; }}
    code {{ color: #00e2bc; }}
    input[type=file] {{
      display: block;
      width: 100%;
      box-sizing: border-box;
      padding: 14px;
      margin: 22px 0;
      border: 1px solid #2a5c6e;
      background: #030c14;
      color: #eaf7fc;
    }}
    button {{
      width: 100%;
      padding: 14px;
      border: 0;
      background: #00e2bc;
      color: #00110e;
      font-weight: 700;
      font-size: 16px;
    }}
    .msg {{ color: #4bff9c; font-weight: 700; }}
  </style>
</head>
<body>
  <main>
    <h1>RGB30 Firmware Upload</h1>
    <p>Keep your computer and RGB30 on the same Wi-Fi, choose a firmware file, then upload it.</p>
    <p>The file will be saved as <code>/storage/firmware.bin</code>.</p>
    {msg}
    <form method="post" action="/upload" enctype="multipart/form-data">
      <input type="file" name="firmware" required>
      <button type="submit">Upload firmware</button>
    </form>
  </main>
</body>
</html>""".encode("utf-8")


def parse_multipart(body, content_type):
    match = re.search(r"boundary=(?:\"([^\"]+)\"|([^;]+))", content_type)
    if not match:
        raise ValueError("missing multipart boundary")
    boundary = (match.group(1) or match.group(2)).encode("utf-8")
    marker = b"--" + boundary
    for part in body.split(marker):
        if b"Content-Disposition:" not in part:
            continue
        header_blob, _, data = part.partition(b"\r\n\r\n")
        if not data:
            continue
        headers = header_blob.decode("utf-8", "replace")
        if 'name="firmware"' not in headers:
            continue
        filename_match = re.search(r'filename="([^"]*)"', headers)
        filename = unquote(filename_match.group(1)) if filename_match else "firmware.bin"
        data = data.rstrip(b"\r\n")
        if data.endswith(b"--"):
            data = data[:-2].rstrip(b"\r\n")
        return filename, data
    raise ValueError("firmware field not found")


class Handler(BaseHTTPRequestHandler):
    server_version = "RGB30FirmwareUpload/1.0"

    def _send(self, status, content, content_type="text/html; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        if self.path == "/status":
            info = {
                "ok": True,
                "target": str(TARGET),
                "exists": TARGET.exists(),
                "size": TARGET.stat().st_size if TARGET.exists() else 0,
                "mtime": int(TARGET.stat().st_mtime) if TARGET.exists() else 0,
            }
            self._send(200, json.dumps(info).encode("utf-8"), "application/json")
            return
        self._send(200, html_page())

    def do_POST(self):
        if self.path != "/upload":
            self._send(404, b"not found", "text/plain")
            return
        length = int(self.headers.get("Content-Length", "0"))
        content_type = self.headers.get("Content-Type", "")
        body = self.rfile.read(length)
        try:
            filename, data = parse_multipart(body, content_type)
            if not data:
                raise ValueError("empty firmware")
            TMP_TARGET.write_bytes(data)
            os.replace(TMP_TARGET, TARGET)
            md5 = hashlib.md5(data).hexdigest()
            LAST_UPLOAD.write_text(
                "%s | %s | %d bytes | %s\n" % (time.strftime("%F %T"), filename, len(data), md5),
                encoding="utf-8",
            )
            msg = "Uploaded %s: %.1f KB, MD5 %s" % (filename, len(data) / 1024.0, md5[:16])
            self._send(200, html_page(msg))
        except Exception as exc:
            self._send(400, html_page("Upload failed: %s" % exc))

    def log_message(self, fmt, *args):
        print("%s - %s" % (self.address_string(), fmt % args), flush=True)


if __name__ == "__main__":
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print("RGB30 firmware upload server listening on %s:%d" % (HOST, PORT), flush=True)
    server.serve_forever()
