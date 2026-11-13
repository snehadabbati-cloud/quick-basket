import http.server
import socketserver
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
DIRECTORY = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

class NoCacheHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def do_GET(self):
        # Clean query parameters and trailing slashes for routing checks
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path in ('/admin', '/store'):
            self.send_response(302)
            self.send_header('Location', '/#/admin')
            self.end_headers()
            return
        super().do_GET()

    def do_HEAD(self):
        clean_path = self.path.split('?')[0].rstrip('/')
        if clean_path in ('/admin', '/store'):
            self.send_response(302)
            self.send_header('Location', '/#/admin')
            self.end_headers()
            return
        super().do_HEAD()

    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()

socketserver.TCPServer.allow_reuse_address = True
try:
    with socketserver.TCPServer(("", PORT), NoCacheHTTPRequestHandler) as httpd:
        print(f"Quick Basket server running at http://localhost:{PORT} with cache-busting headers")
        sys.stdout.flush()
        httpd.serve_forever()
except Exception as e:
    print(f"Server error on port {PORT}: {e}")
    sys.stdout.flush()
