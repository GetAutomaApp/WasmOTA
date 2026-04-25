#!/usr/bin/env python3

from __future__ import annotations

import hashlib
import mimetypes
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


ROOT = Path(__file__).resolve().parent
ASSETS_DIR = ROOT / "assets"
HOST = os.environ.get("OTA_TEST_SERVER_HOST", "127.0.0.1")
PORT = int(os.environ.get("OTA_TEST_SERVER_PORT", "8000"))


def compute_etag(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return f"\"{digest.hexdigest()}\""


class OTATestRequestHandler(BaseHTTPRequestHandler):
    server_version = "OTATestServer/0.1"

    def do_HEAD(self) -> None:
        self._serve(send_body=False)

    def do_GET(self) -> None:
        self._serve(send_body=True)

    def _serve(self, send_body: bool) -> None:
        path = self._resolve_path()
        if path is None:
            self.send_error(HTTPStatus.NOT_FOUND, "File not found")
            return

        etag = compute_etag(path)
        if self.headers.get("If-None-Match") == etag:
            self.send_response(HTTPStatus.NOT_MODIFIED)
            self.send_header("ETag", etag)
            self.end_headers()
            return

        content_type, _ = mimetypes.guess_type(path.name)
        stat = path.stat()

        self.send_response(HTTPStatus.OK)
        self.send_header("Content-Type", content_type or "application/octet-stream")
        self.send_header("Content-Length", str(stat.st_size))
        self.send_header("ETag", etag)
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()

        if send_body:
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(64 * 1024), b""):
                    self.wfile.write(chunk)

    def _resolve_path(self) -> Path | None:
        request_path = unquote(urlparse(self.path).path).lstrip("/")
        if not request_path:
            return None

        candidate = (ASSETS_DIR / request_path).resolve()
        if not candidate.is_file():
            return None

        try:
            candidate.relative_to(ASSETS_DIR.resolve())
        except ValueError:
            return None

        return candidate


def main() -> None:
    ASSETS_DIR.mkdir(exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), OTATestRequestHandler)
    print(f"Serving {ASSETS_DIR} on http://{HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    main()
