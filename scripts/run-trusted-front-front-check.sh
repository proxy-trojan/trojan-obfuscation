#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "usage: $0 <bundle_dir> <host> <trusted_front_port> [server_name] [output_file]" >&2
  exit 2
fi

BUNDLE_DIR="$1"
HOST="$2"
PORT="$3"
SERVER_NAME="${4:-localhost}"
OUTPUT_FILE="${5:-$BUNDLE_DIR/front/front-check-response.txt}"

CA_FILE="$BUNDLE_DIR/shared/ca.crt"
CLIENT_CERT="$BUNDLE_DIR/front/trusted-front-client.crt"
CLIENT_KEY="$BUNDLE_DIR/front/trusted-front-client.key"
ENVELOPE_FILE="$BUNDLE_DIR/front/envelope.json"
PAYLOAD_FILE="$BUNDLE_DIR/front/downstream.txt"

mkdir -p "$BUNDLE_DIR/front"

if [[ ! -f "$ENVELOPE_FILE" ]]; then
  cat > "$ENVELOPE_FILE" <<'EOF'
{"source_name":"two-host-front","trusted_front_id":"two-host-front-id","original_client_ip":"203.0.113.10","original_client_port":44321,"server_name":"front.example.com","negotiated_alpn":"h2","tls_terminated_by_front":true,"metadata_verified":true}
EOF
fi

if [[ ! -f "$PAYLOAD_FILE" ]]; then
  printf 'GET / HTTP/1.1\r\nHost: localhost\r\n\r\n' > "$PAYLOAD_FILE"
fi

python3 "$(dirname "$0")/send-trusted-front-frame.py" \
  --host "$HOST" \
  --port "$PORT" \
  --server-name "$SERVER_NAME" \
  --ca "$CA_FILE" \
  --cert "$CLIENT_CERT" \
  --key "$CLIENT_KEY" \
  --envelope-json-file "$ENVELOPE_FILE" \
  --payload-file "$PAYLOAD_FILE" \
  --output "$OUTPUT_FILE"

echo "trusted-front front-side check complete"
echo "response=$OUTPUT_FILE"
