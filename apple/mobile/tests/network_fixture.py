"""Loopback-only transport fixture. Synthetic bytes, no user credentials."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import time


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == '/redirect':
            self.send_response(302)
            self.send_header('Location', '/followed')
            self.end_headers()
            return
        self.send_response(200)
        self.end_headers()  # deliberately no Content-Length
        try:
            if self.path == '/slow':
                self.wfile.write(b'x')
                self.wfile.flush()
                time.sleep(2)
            self.wfile.write(b'x' * (65536 if self.path == '/large' else 1))
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == '__main__':
    ThreadingHTTPServer(('127.0.0.1', 8018), Handler).serve_forever()
