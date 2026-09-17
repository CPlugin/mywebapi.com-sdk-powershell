#!/usr/bin/env python3
"""Deterministic loopback HTTP/SignalR stand-in for the published MyWebApi module."""
import argparse
import base64
import hashlib
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, unquote, urlsplit


class State:
    def __init__(self, state_file):
        self.state_file = state_file
        self.lock = threading.Lock()
        self.requests = []
        self.token_count = 0
        self.write_count = 0
        self.ws_events = []

    def snapshot(self):
        with self.lock:
            return {
                "token_count": self.token_count,
                "write_count": self.write_count,
                "requests": list(self.requests),
                "ws_events": list(self.ws_events),
            }

    def save(self):
        tmp = self.state_file + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.snapshot(), f, separators=(",", ":"))
        os.replace(tmp, self.state_file)

    def add_request(self, item):
        with self.lock:
            self.requests.append(item)
        self.save()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        return

    @property
    def state(self):
        return self.server.audit_state

    @property
    def parts(self):
        return urlsplit(self.path)

    def _read_body(self):
        try:
            n = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            n = 0
        return self.rfile.read(n) if n else b""

    def _record(self, method, body=b""):
        parts = self.parts
        query = parse_qs(parts.query, keep_blank_values=True)
        item = {
            "method": method,
            "raw": self.path,
            "path": unquote(parts.path),
            "query": query,
            "has_authorization": bool(self.headers.get("Authorization")),
            "has_signalr_token": "signalr_token" in query,
            "idempotency_key": self.headers.get("Idempotency-Key"),
        }
        if body:
            item["body_sha256"] = hashlib.sha256(body).hexdigest()
            if self.headers.get("Content-Type", "").startswith("application/json"):
                try:
                    parsed = json.loads(body.decode("utf-8"))
                    item["body"] = parsed
                except Exception:
                    item["body_is_json"] = False
        if parts.path == "/oauth/token":
            form = parse_qs(body.decode("utf-8"), keep_blank_values=True)
            item["oauth_form"] = {
                "grant_type": form.get("grant_type", [None])[0],
                "client_id": form.get("client_id", [None])[0],
                "scope": form.get("scope", [None])[0],
                "secret_present": bool(form.get("client_secret", [""])[0]),
            }
        self.state.add_request(item)
        return parts, query

    def _send(self, status, payload, content_type="application/json"):
        raw = payload if isinstance(payload, bytes) else json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.headers.get("Upgrade", "").lower() == "websocket":
            self._websocket()
            return
        parts, query = self._record("GET")
        path = unquote(parts.path)
        if path == "/__state":
            self._send(200, self.state.snapshot())
        elif path == "/.well-known/openid-configuration":
            target_port = self.server.server_port
            target_file = getattr(self.server, "token_target_file", None)
            if target_file and os.path.exists(target_file):
                target_port = int(open(target_file, encoding="utf-8").read().strip())
            self._send(200, {"token_endpoint": f"http://127.0.0.1:{target_port}/oauth/token"})
        elif path == "/api/TradePlatforms":
            self._send(200, [{"id": "tp/alpha one", "name": "synthetic"}])
        elif path.endswith("/UsersRequest"):
            cursor = query.get("cursor", [None])[0]
            if cursor == "next cursor":
                self._send(200, {"data": [{"login": 3}], "meta": {"paging": {"hasMore": False, "nextCursor": None}}})
            else:
                self._send(200, {"data": [{"login": 1}, {"login": 2}], "meta": {"paging": {"hasMore": True, "nextCursor": "next cursor"}}})
        elif path.endswith("/ServerTime"):
            if "/error/" in path:
                self._send(200, {"error": {"code": "synthetic.failure", "message": "simulated failure", "managerCode": "M1"}, "meta": {"activityId": "activity-1"}})
            elif "/unauthorized/" in path:
                self._send(401, {"error": {"code": "synthetic.unauthorized", "message": "synthetic unauthorized"}})
            elif "/http503/" in path:
                self._send(503, {"error": {"code": "synthetic.unavailable", "message": "temporary unavailable"}})
            else:
                # spec DateTimeApiResponse has a scalar DateTime data field.
                self._send(200, {"data": "2026-09-17T00:00:00Z"})
        else:
            self._send(404, {"error": {"code": "not_found", "message": "synthetic route not found"}})

    def do_POST(self):
        body = self._read_body()
        parts, query = self._record("POST", body)
        path = unquote(parts.path)
        if path == "/oauth/token":
            with self.state.lock:
                self.state.token_count += 1
                token_no = self.state.token_count
            self.state.save()
            self._send(200, {"access_token": f"oauth-token-{token_no}", "token_type": "Bearer", "expires_in": 3600})
        elif path.endswith("/negotiate"):
            # A normal negotiate response has no redirect URL; the client upgrades the original URL.
            self._send(200, {
                "connectionId": "synthetic-connection",
                "connectionToken": "synthetic-token",
                "negotiateVersion": 1,
                "availableTransports": [
                    {"transport": "WebSockets", "transferFormats": ["Text", "Binary"]}
                ],
            })
        elif path.endswith("/AdmBalanceFix"):
            with self.state.lock:
                self.state.write_count += 1
            self.state.save()
            self._send(200, {"data": {"accepted": True}})
        else:
            self._send(200, {"data": {"accepted": True}})

    def do_PATCH(self):
        body = self._read_body()
        self._record("PATCH", body)
        with self.state.lock:
            self.state.write_count += 1
        self.state.save()
        self._send(200, {"data": {"accepted": True}})

    def _recv_frame(self, timeout=5):
        self.connection.settimeout(timeout)
        first = self.connection.recv(2)
        if len(first) < 2:
            return None, b""
        b1, b2 = first
        opcode = b1 & 0x0F
        length = b2 & 0x7F
        if length == 126:
            length = int.from_bytes(self.connection.recv(2), "big")
        elif length == 127:
            length = int.from_bytes(self.connection.recv(8), "big")
        masked = bool(b2 & 0x80)
        mask = self.connection.recv(4) if masked else b""
        payload = b""
        while len(payload) < length:
            part = self.connection.recv(length - len(payload))
            if not part:
                break
            payload += part
        if masked:
            payload = bytes(x ^ mask[i % 4] for i, x in enumerate(payload))
        return opcode, payload

    def _send_frame(self, payload, opcode=1):
        if isinstance(payload, str):
            payload = payload.encode("utf-8")
        n = len(payload)
        if n < 126:
            head = bytes([0x80 | opcode, n])
        elif n <= 0xFFFF:
            head = bytes([0x80 | opcode, 126]) + n.to_bytes(2, "big")
        else:
            head = bytes([0x80 | opcode, 127]) + n.to_bytes(8, "big")
        self.connection.sendall(head + payload)

    def _websocket(self):
        key = self.headers.get("Sec-WebSocket-Key", "")
        accept = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        self.send_response(101, "Switching Protocols")
        self.send_header("Upgrade", "websocket")
        self.send_header("Connection", "Upgrade")
        self.send_header("Sec-WebSocket-Accept", accept)
        self.end_headers()
        with self.state.lock:
            self.state.ws_events.append({"event": "connected", "path": self.path, "has_signalr_token": "signalr_token" in parse_qs(self.parts.query)})
        self.state.save()
        try:
            opcode, payload = self._recv_frame()
            if opcode != 1:
                return
            text = payload.decode("utf-8", "replace")
            if "\x1e" not in text:
                return
            self._send_frame("{}\x1e")
            self._send_frame(json.dumps({"type": 1, "target": "OnConnectionStatus", "arguments": [{"state": "connected"}]}, separators=(",", ":")) + "\x1e")
            while True:
                opcode, payload = self._recv_frame(timeout=10)
                if opcode is None or opcode == 8:
                    return
                if opcode != 1:
                    continue
                for line in payload.decode("utf-8", "replace").split("\x1e"):
                    if not line:
                        continue
                    try:
                        msg = json.loads(line)
                    except Exception:
                        continue
                    if msg.get("target") == "SubscribeToTicks":
                        iid = msg.get("invocationId")
                        if iid is not None:
                            self._send_frame(json.dumps({"type": 3, "invocationId": iid}, separators=(",", ":")) + "\x1e")
                        self._send_frame(json.dumps({"type": 1, "target": "OnTick", "arguments": [{"symbol": "EURUSD", "bid": 1.1, "ask": 1.2}]}, separators=(",", ":")) + "\x1e")
        except (OSError, TimeoutError):
            return


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=0)
    ap.add_argument("--state-file", required=True)
    ap.add_argument("--port-file", required=True)
    ap.add_argument("--token-target-file")
    args = ap.parse_args()
    state = State(args.state_file)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.audit_state = state
    server.token_target_file = args.token_target_file
    with open(args.port_file, "w", encoding="utf-8") as f:
        f.write(str(server.server_port))
    state.save()
    try:
        server.serve_forever(poll_interval=0.05)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
