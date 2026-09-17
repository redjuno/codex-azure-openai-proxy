#!/usr/bin/env python3
import http.server
import os
import sys


class Server(http.server.ThreadingHTTPServer):
    allow_reuse_address = True


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        token = os.environ["LITELLM_MASTER_KEY"]
        authorized = (
            self.headers.get("Authorization") == f"Bearer {token}"
            and self.headers.get("x-api-key") == token
        )
        if self.path == "/health/readiness" and authorized:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'{"status":"healthy"}')
        else:
            self.send_response(401 if not authorized else 404)
            self.end_headers()

    def log_message(self, _format, *_args):
        pass


server = Server((os.environ["LITELLM_HOST"], int(os.environ["LITELLM_PORT"])), Handler)
with open(os.environ["MOCK_PROXY_STARTS"], "a", encoding="utf-8") as starts:
    starts.write(f"{os.getpid()}\n")
server.serve_forever()
