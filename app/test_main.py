import threading
import unittest
import urllib.error
import urllib.request
from http.server import HTTPServer

from main import Handler


class HealthTest(unittest.TestCase):
    def setUp(self):
        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.port = self.server.server_address[1]
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()

    def test_healthz(self):
        r = urllib.request.urlopen(f"http://127.0.0.1:{self.port}/healthz")
        self.assertEqual(r.status, 200)
        self.assertEqual(r.read(), b"ok")

    def test_unknown_path_is_404(self):
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(f"http://127.0.0.1:{self.port}/nope")
        self.assertEqual(ctx.exception.code, 404)


if __name__ == "__main__":
    unittest.main()