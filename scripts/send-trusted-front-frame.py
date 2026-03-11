#!/usr/bin/env python3
import argparse
import pathlib
import socket
import ssl
import sys


def read_text_arg(value: str | None, path: str | None) -> str:
    if value is not None and path is not None:
        raise SystemExit("choose either inline text or file path, not both")
    if path is not None:
        return pathlib.Path(path).read_text()
    return value or ""


def read_bytes_arg(value: str | None, path: str | None) -> bytes:
    if value is not None and path is not None:
        raise SystemExit("choose either inline payload text or payload file, not both")
    if path is not None:
        return pathlib.Path(path).read_bytes()
    return (value or "").encode()


def main() -> int:
    parser = argparse.ArgumentParser(description="Send trusted-front envelope + downstream payload over mTLS")
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", required=True, type=int)
    parser.add_argument("--server-name", default="localhost")
    parser.add_argument("--ca", required=True)
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--envelope-json")
    parser.add_argument("--envelope-json-file")
    parser.add_argument("--payload-text")
    parser.add_argument("--payload-file")
    parser.add_argument("--timeout", type=float, default=5.0)
    parser.add_argument("--output")
    args = parser.parse_args()

    envelope_json = read_text_arg(args.envelope_json, args.envelope_json_file).strip()
    if not envelope_json:
        raise SystemExit("trusted-front envelope JSON is required")

    downstream_payload = read_bytes_arg(args.payload_text, args.payload_file)
    if not downstream_payload:
        raise SystemExit("downstream payload is required")

    envelope_bytes = envelope_json.encode()
    frame = str(len(envelope_bytes)).encode() + b"\n" + envelope_bytes + downstream_payload

    ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=args.ca)
    ctx.load_cert_chain(certfile=args.cert, keyfile=args.key)
    ctx.check_hostname = False

    output = b""
    with socket.create_connection((args.host, args.port), timeout=args.timeout) as sock:
        with ctx.wrap_socket(sock, server_hostname=args.server_name) as tls_sock:
            tls_sock.settimeout(args.timeout)
            tls_sock.sendall(frame)
            try:
                while True:
                    chunk = tls_sock.recv(4096)
                    if not chunk:
                        break
                    output += chunk
                    if len(chunk) < 4096:
                        break
            except TimeoutError:
                pass

    if args.output:
        pathlib.Path(args.output).write_bytes(output)
    else:
        sys.stdout.buffer.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
