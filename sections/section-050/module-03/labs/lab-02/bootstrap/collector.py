# The audit collector of the lab: an HTTPS receiver on 127.0.0.1:8443 that
# accepts audit EventList batches with the bearer token training-audit-token
# and appends each event as one JSON line to /var/log/audit-collector/events.jsonl.
import http.server
import json
import ssl

TOKEN = 'Bearer training-audit-token'
LOG = '/var/log/audit-collector/events.jsonl'


class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        if self.headers.get('Authorization') != TOKEN:
            self.send_response(401)
            self.end_headers()
            return
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        with open(LOG, 'a') as log:
            for event in body.get('items', []):
                log.write(json.dumps(event) + '\n')
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'{}')

    def log_message(self, *args):
        pass


server = http.server.HTTPServer(('127.0.0.1', 8443), Handler)
context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
context.load_cert_chain('/etc/audit-collector/collector.crt', '/etc/audit-collector/collector.key')
server.socket = context.wrap_socket(server.socket, server_side=True)
server.serve_forever()
