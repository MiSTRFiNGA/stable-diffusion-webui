"""
JARVIS II — Thin Client Controller
Receives intent commands locally, proxies all generation/inference requests
to the HiVEMiND machine over Tailscale.
"""

import json
import logging
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

# Insert jarvis_mobile onto path so jarvis_config is importable regardless of cwd
import os
sys.path.insert(0, os.path.dirname(__file__))
import jarvis_config as cfg

logging.basicConfig(
    level=getattr(logging, cfg.LOG_LEVEL, logging.INFO),
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("jarvis.controller")


# ─── Remote Proxy Helper ────────────────────────────────────────────────────────

def proxy_request(service: str, path: str, method: str = "GET",
                  body: bytes = b"", headers: dict = None) -> dict:
    """Forward a request to a named remote service on HiVEMiND."""
    base_url = cfg.resolve_endpoint(service)
    url = f"{base_url}{path}"
    req_headers = {"Content-Type": "application/json"}
    if headers:
        req_headers.update(headers)

    req = Request(url, data=body or None, headers=req_headers, method=method)
    try:
        with urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return {"status": resp.status, "body": json.loads(raw) if raw else {}}
    except HTTPError as e:
        return {"status": e.code, "error": e.reason}
    except URLError as e:
        return {"status": 0, "error": str(e.reason)}


# ─── Dummy Probe ───────────────────────────────────────────────────────────────

def probe_hivemind() -> bool:
    """Send a lightweight GET to the HiVEMiND FastAPI health endpoint."""
    log.info("Probing HiVEMiND FastAPI at %s …", cfg.ENDPOINTS["fastapi"])
    result = proxy_request("fastapi", "/health")
    if result.get("status") == 200:
        log.info("HiVEMiND FastAPI responded: %s", result.get("body"))
        return True
    # Fallback: try root path
    result = proxy_request("fastapi", "/")
    if result.get("status") in (200, 307, 404):
        log.info("HiVEMiND FastAPI reachable (status %s).", result.get("status"))
        return True
    log.warning("HiVEMiND FastAPI not responding. Error: %s", result.get("error"))
    return False


# ─── Local HTTP Controller ──────────────────────────────────────────────────────

class JARVISHandler(BaseHTTPRequestHandler):
    """Minimal local API gateway — accepts intents and forwards to HiVEMiND."""

    def log_message(self, fmt, *args):  # redirect to our logger
        log.debug("HTTP %s", fmt % args)

    def _respond(self, code: int, payload: dict):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/status":
            online = cfg.check_tailscale_connectivity()
            self._respond(200, {
                "mode": cfg.MODE,
                "hivemind_ip": cfg.HIVEMIND_TAILSCALE_IP,
                "tailscale_online": online,
                "endpoints": cfg.ENDPOINTS,
            })

        elif parsed.path == "/probe":
            ok = probe_hivemind()
            self._respond(200 if ok else 503, {"hivemind_reachable": ok})

        elif parsed.path.startswith("/proxy/"):
            # /proxy/<service><remote_path>  e.g. /proxy/sdwebui/sdapi/v1/options
            parts = parsed.path[len("/proxy/"):].split("/", 1)
            service = parts[0]
            remote_path = "/" + parts[1] if len(parts) > 1 else "/"
            result = proxy_request(service, remote_path)
            self._respond(result.get("status", 500) or 500, result)

        else:
            self._respond(404, {"error": "Unknown route", "path": parsed.path})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""
        parsed = urlparse(self.path)

        if parsed.path.startswith("/proxy/"):
            parts = parsed.path[len("/proxy/"):].split("/", 1)
            service = parts[0]
            remote_path = "/" + parts[1] if len(parts) > 1 else "/"
            result = proxy_request(service, remote_path, method="POST", body=body)
            self._respond(result.get("status", 500) or 500, result)
        else:
            self._respond(404, {"error": "Unknown route"})


def run_controller():
    cfg.assert_controller_mode()
    cfg.print_config()

    log.info("Checking Tailscale connectivity to HiVEMiND (%s)…", cfg.HIVEMIND_TAILSCALE_IP)
    if cfg.check_tailscale_connectivity():
        log.info("Tailscale: HiVEMiND is REACHABLE.")
    else:
        log.warning("Tailscale: HiVEMiND NOT reachable via ping. Proceeding anyway — TCP may still work.")

    server = HTTPServer((cfg.LOCAL_HOST, cfg.LOCAL_CONTROLLER_PORT), JARVISHandler)
    log.info("JARVIS Controller listening on %s:%d", cfg.LOCAL_HOST, cfg.LOCAL_CONTROLLER_PORT)
    print("\n  Mobile Brain initialized. Headless Controller ready.\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Controller shut down by user.")
        server.server_close()


if __name__ == "__main__":
    run_controller()
