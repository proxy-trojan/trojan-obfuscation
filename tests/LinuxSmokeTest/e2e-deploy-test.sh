#!/usr/bin/env bash
# ============================================================================
# e2e-deploy-test.sh
#
# 一键部署并端到端测试 Trojan server + client 全链路连通性。
# 在单机上使用自签证书 + 动态端口，零外部依赖。
#
# 架构:
#   curl ──SOCKS5──→ Trojan Client ──TLS──→ Trojan Server ──TCP──→ Target HTTP
#                                                │ (非 Trojan 流量)
#                                                └──→ Fallback HTTP
#
# 依赖: python3, openssl, curl
# 用法: bash e2e-deploy-test.sh <trojan-binary>
# ============================================================================
set -euo pipefail

TROJAN_BIN="${1:-}"
if [[ -z "$TROJAN_BIN" ]]; then
  echo "usage: $0 <trojan-binary>" >&2
  exit 2
fi

if [[ ! -x "$TROJAN_BIN" ]]; then
  echo "trojan binary not found or not executable: $TROJAN_BIN" >&2
  exit 2
fi

# --- 依赖检查 ---
for cmd in python3 openssl curl; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "required: $cmd" >&2; exit 2; }
done

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TMPDIR="$(mktemp -d)"

# --- 进程管理 ---
SERVER_PID=""
CLIENT_PID=""
FALLBACK_PID=""
TARGET_PID=""
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
  for pid in "$CLIENT_PID" "$SERVER_PID" "$TARGET_PID" "$FALLBACK_PID"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# --- 辅助函数 ---
log_info()  { echo -e "\033[0;36m[INFO]\033[0m  $*"; }
log_pass()  { echo -e "\033[0;32m[PASS]\033[0m  $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
log_fail()  { echo -e "\033[0;31m[FAIL]\033[0m  $*"; FAIL_COUNT=$((FAIL_COUNT + 1)); }

# 等待端口可接受连接
wait_for_port() {
  local port="$1"
  local label="${2:-service}"
  python3 - <<'PY' "$port" "$label"
import socket, sys, time
port = int(sys.argv[1])
label = sys.argv[2]
deadline = time.time() + 15
while time.time() < deadline:
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=0.5):
            pass
        sys.exit(0)
    except OSError:
        time.sleep(0.2)
print(f'{label} did not start listening on port {port} in time', file=sys.stderr)
sys.exit(1)
PY
}

# 等待 HTTP 服务就绪（返回 200）
wait_for_http() {
  local port="$1"
  local label="${2:-http}"
  local deadline=$((SECONDS + 15))
  while [[ $SECONDS -lt $deadline ]]; do
    if curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$port/" 2>/dev/null | grep -q "200"; then
      return 0
    fi
    sleep 0.3
  done
  echo "$label did not respond 200 on port $port in time" >&2
  return 1
}

wait_for_log() {
  local log_path="$1"
  local expected="$2"
  local label="${3:-log line}"
  python3 - <<'PY' "$log_path" "$expected" "$label"
import pathlib, sys, time
path = pathlib.Path(sys.argv[1])
needle = sys.argv[2]
label = sys.argv[3]
deadline = time.time() + 10
while time.time() < deadline:
    text = path.read_text(encoding='utf-8', errors='replace') if path.exists() else ''
    if needle in text:
        sys.exit(0)
    time.sleep(0.1)
print(f'missing {label}: {needle}', file=sys.stderr)
if path.exists():
    print(path.read_text(encoding='utf-8', errors='replace'), file=sys.stderr)
sys.exit(1)
PY
}

# ============================================================================
# 1. 分配动态端口
# ============================================================================
log_info "分配动态端口..."

read -r TROJAN_PORT FALLBACK_PORT SOCKS5_PORT TARGET_PORT < <(python3 - <<'PY'
import socket
ports = []
for _ in range(4):
    s = socket.socket()
    s.bind(('127.0.0.1', 0))
    ports.append(s.getsockname()[1])
    s.close()
print(ports[0], ports[1], ports[2], ports[3])
PY
)

log_info "Trojan Server 端口: $TROJAN_PORT"
log_info "Fallback HTTP 端口: $FALLBACK_PORT"
log_info "SOCKS5 代理端口:    $SOCKS5_PORT"
log_info "目标 HTTP 服务端口: $TARGET_PORT"

# ============================================================================
# 2. 生成自签证书
# ============================================================================
log_info "生成自签 TLS 证书..."

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout "$TMPDIR/server.key" \
  -out "$TMPDIR/server.crt" \
  -days 1 \
  -subj "/CN=localhost" >/dev/null 2>&1

# ============================================================================
# 3. 启动模拟 HTTP 服务
# ============================================================================

# 3a. Fallback 后端（模拟正常网站，非 Trojan 流量转发到这里）
log_info "启动 Fallback HTTP 后端 (端口 $FALLBACK_PORT)..."

python3 - <<'PY' "$FALLBACK_PORT" "$TMPDIR" &
import http.server, sys, os

port = int(sys.argv[1])
tmpdir = sys.argv[2]

class FallbackHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"FALLBACK_OK")

    def log_message(self, *args):
        pass  # 静默日志

os.chdir(tmpdir)
server = http.server.ThreadingHTTPServer(('127.0.0.1', port), FallbackHandler)
server.serve_forever()
PY
FALLBACK_PID=$!

# 3b. 目标 HTTP 服务（Trojan 隧道穿透后实际到达的站点）
log_info "启动目标 HTTP 服务 (端口 $TARGET_PORT)..."

python3 - <<'PY' "$TARGET_PORT" "$TMPDIR" &
import http.server, sys, os

port = int(sys.argv[1])
tmpdir = sys.argv[2]

class TargetHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"TARGET_OK")

    def log_message(self, *args):
        pass  # 静默日志

os.chdir(tmpdir)
server = http.server.ThreadingHTTPServer(('127.0.0.1', port), TargetHandler)
server.serve_forever()
PY
TARGET_PID=$!

wait_for_http "$FALLBACK_PORT" "Fallback"
wait_for_http "$TARGET_PORT" "Target"

# ============================================================================
# 4. 生成 Trojan 配置文件
# ============================================================================
log_info "生成 Trojan 配置..."

# 4a. Server 配置
cat > "$TMPDIR/server.json" <<EOF
{
  "run_type": "server",
  "local_addr": "127.0.0.1",
  "local_port": ${TROJAN_PORT},
  "remote_addr": "127.0.0.1",
  "remote_port": ${FALLBACK_PORT},
  "password": ["e2e-test-password-2026"],
  "log_level": 0,
  "ssl": {
    "cert": "$TMPDIR/server.crt",
    "key": "$TMPDIR/server.key",
    "key_password": "",
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
    "prefer_server_cipher": true,
    "alpn": ["http/1.1"],
    "alpn_port_override": {},
    "reuse_session": true,
    "session_ticket": false,
    "session_timeout": 600,
    "plain_http_response": "",
    "curves": "",
    "dhparam": ""
  },
  "threads": 4,
  "tcp": {
    "prefer_ipv4": false,
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "fast_open": false,
    "fast_open_qlen": 20
  },
  "mysql": {
    "enabled": false,
    "server_addr": "127.0.0.1",
    "server_port": 3306,
    "database": "trojan",
    "username": "trojan",
    "password": "",
    "key": "",
    "cert": "",
    "ca": ""
  },
  "abuse_control": {
    "enabled": true,
    "per_ip_max_connections": 64,
    "auth_fail_window_seconds": 60,
    "auth_fail_max": 20,
    "cooldown_seconds": 60,
    "fallback_max_active": 32
  }
}
EOF

# 4b. Client 配置
cat > "$TMPDIR/client.json" <<EOF
{
  "run_type": "client",
  "local_addr": "127.0.0.1",
  "local_port": ${SOCKS5_PORT},
  "remote_addr": "127.0.0.1",
  "remote_port": ${TROJAN_PORT},
  "password": ["e2e-test-password-2026"],
  "log_level": 0,
  "ssl": {
    "verify": false,
    "verify_hostname": false,
    "cert": "",
    "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA",
    "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
    "sni": "localhost",
    "alpn": ["h2", "http/1.1"],
    "reuse_session": true,
    "session_ticket": false,
    "curves": ""
  },
  "tcp": {
    "no_delay": true,
    "keep_alive": true,
    "reuse_port": false,
    "fast_open": false,
    "fast_open_qlen": 20
  }
}
EOF

# ============================================================================
# 5. 启动 Trojan Server + Client
# ============================================================================
log_info "启动 Trojan Server..."
"$TROJAN_BIN" -c "$TMPDIR/server.json" -l "$TMPDIR/server.log" >"$TMPDIR/server.stdout" 2>&1 &
SERVER_PID=$!
wait_for_port "$TROJAN_PORT" "Trojan Server"
log_info "Trojan Server 已启动 (PID: $SERVER_PID)"

log_info "启动 Trojan Client..."
"$TROJAN_BIN" -c "$TMPDIR/client.json" -l "$TMPDIR/client.log" >"$TMPDIR/client.stdout" 2>&1 &
CLIENT_PID=$!
wait_for_port "$SOCKS5_PORT" "Trojan Client"
log_info "Trojan Client 已启动 (PID: $CLIENT_PID)"

# ============================================================================
# 6. E2E 测试用例
# ============================================================================
echo ""
log_info "========== 开始 E2E 测试 =========="
echo ""

# --- Test 1: SOCKS5 代理连通性 ---
log_info "Test 1: SOCKS5 代理连通性测试"
RESPONSE=$(curl -s --max-time 10 \
  --socks5-hostname "127.0.0.1:$SOCKS5_PORT" \
  "http://127.0.0.1:$TARGET_PORT/" 2>/dev/null || echo "CURL_FAILED")

if [[ "$RESPONSE" == "TARGET_OK" ]]; then
  log_pass "Test 1: 通过 SOCKS5 代理成功访问目标服务，响应正确"
else
  log_fail "Test 1: SOCKS5 代理连通性失败 (响应: $RESPONSE)"
  echo "--- Server 日志 ---" >&2
  cat "$TMPDIR/server.log" 2>/dev/null || true
  echo "--- Client 日志 ---" >&2
  cat "$TMPDIR/client.log" 2>/dev/null || true
fi

# --- Test 2: Fallback 行为验证 ---
log_info "Test 2: Fallback 行为验证（非 Trojan 流量应转发到伪装站点）"
FALLBACK_RESPONSE=$(python3 - <<'PY' "$TROJAN_PORT"
import socket, ssl, sys
port = int(sys.argv[1])
ctx = ssl._create_unverified_context()
# 发送普通 HTTP GET 请求（非 Trojan 协议），应被 fallback 到伪装站点
payload = b"GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
try:
    with socket.create_connection(('127.0.0.1', port), timeout=5) as sock:
        with ctx.wrap_socket(sock, server_hostname='localhost') as tls:
            tls.sendall(payload)
            data = b""
            while True:
                chunk = tls.recv(4096)
                if not chunk:
                    break
                data += chunk
            response = data.decode('utf-8', errors='replace')
            if 'FALLBACK_OK' in response:
                print('FALLBACK_OK')
            else:
                print(f'UNEXPECTED: {response[:200]}')
except Exception as e:
    print(f'ERROR: {e}')
PY
)

if [[ "$FALLBACK_RESPONSE" == "FALLBACK_OK" ]]; then
  log_pass "Test 2: 非 Trojan 流量正确转发到 Fallback 后端"
else
  log_fail "Test 2: Fallback 行为异常 (响应: $FALLBACK_RESPONSE)"
fi

# --- Test 3: 错误密码拒绝 ---
log_info "Test 3: 错误密码认证拒绝测试"
WRONG_AUTH_RESULT=$(python3 - <<'PY' "$TROJAN_PORT"
import hashlib, socket, ssl, sys
port = int(sys.argv[1])
ctx = ssl._create_unverified_context()
# 构造一个使用错误密码的 Trojan 请求
wrong_password = "wrong-password-definitely-invalid"
token = hashlib.sha224(wrong_password.encode()).hexdigest()
# Trojan 请求格式: <SHA224(password)>\r\n<CMD><ATYP><DST.ADDR><DST.PORT>\r\n
# CMD=0x01 (CONNECT), ATYP=0x03 (域名), 域名长度+域名, 端口
target_host = b"example.com"
payload = token.encode() + b"\r\n"
payload += bytes([0x01, 0x03, len(target_host)]) + target_host + bytes([0x00, 0x50])
payload += b"\r\n"
try:
    with socket.create_connection(('127.0.0.1', port), timeout=5) as sock:
        with ctx.wrap_socket(sock, server_hostname='localhost') as tls:
            tls.sendall(payload)
            # 服务器应将此视为认证失败；随后可能关闭连接，也可能把原始负载交给 fallback。
            data = tls.recv(4096)
            response = data.decode('utf-8', errors='replace')
            if 'TARGET_OK' in response:
                print(f'UNEXPECTED_TARGET: {response[:200]}')
            else:
                print('REJECTED_OK')
except (ConnectionResetError, BrokenPipeError, ssl.SSLError):
    # 连接被重置也是预期行为
    print('REJECTED_OK')
except Exception as e:
    print(f'ERROR: {e}')
PY
)

auth_fail_seen="false"
if wait_for_log "$TMPDIR/server.log" "valid trojan request structure but authentication failed" "auth failure log"; then
  auth_fail_seen="true"
fi

if [[ "$WRONG_AUTH_RESULT" == "REJECTED_OK" && "$auth_fail_seen" == "true" ]]; then
  log_pass "Test 3: 错误密码请求被正确拒绝，并进入 auth-failure/fallback 路径"
else
  log_fail "Test 3: 错误密码处理异常 (结果: $WRONG_AUTH_RESULT, auth_fail_seen: $auth_fail_seen)"
fi

# --- Test 4: 并发连接稳定性 ---
log_info "Test 4: 并发连接稳定性测试 (5 个并发请求)"
CONCURRENT_PIDS=()
CONCURRENT_RESULTS="$TMPDIR/concurrent"
mkdir -p "$CONCURRENT_RESULTS"

for i in $(seq 1 5); do
  (
    result=$(curl -s --max-time 20 \
      --socks5-hostname "127.0.0.1:$SOCKS5_PORT" \
      "http://127.0.0.1:$TARGET_PORT/" 2>/dev/null || echo "CURL_FAILED")
    echo "$result" > "$CONCURRENT_RESULTS/$i.txt"
  ) &
  CONCURRENT_PIDS+=($!)
done

# 等待所有并发请求完成
CONCURRENT_OK=0
CONCURRENT_FAIL=0
for pid in "${CONCURRENT_PIDS[@]}"; do
  wait "$pid" 2>/dev/null || true
done

for i in $(seq 1 5); do
  if [[ -f "$CONCURRENT_RESULTS/$i.txt" ]]; then
    result=$(cat "$CONCURRENT_RESULTS/$i.txt")
    if [[ "$result" == "TARGET_OK" ]]; then
      CONCURRENT_OK=$((CONCURRENT_OK + 1))
    else
      CONCURRENT_FAIL=$((CONCURRENT_FAIL + 1))
    fi
  else
    CONCURRENT_FAIL=$((CONCURRENT_FAIL + 1))
  fi
done

if [[ $CONCURRENT_OK -eq 5 ]]; then
  log_pass "Test 4: 5/5 并发请求全部成功"
elif [[ $CONCURRENT_OK -ge 3 ]]; then
  log_pass "Test 4: $CONCURRENT_OK/5 并发请求成功 ($CONCURRENT_FAIL 失败，可接受)"
else
  log_fail "Test 4: 并发测试失败 ($CONCURRENT_OK/5 成功)"
fi

# ============================================================================
# 7. 汇总结果
# ============================================================================
echo ""
log_info "========== 测试结果汇总 =========="
echo ""
log_info "通过: $PASS_COUNT"
log_info "失败: $FAIL_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  log_fail "E2E 测试存在失败用例"
  echo "" >&2
  echo "--- Server 日志（最后 50 行）---" >&2
  tail -n 50 "$TMPDIR/server.log" 2>/dev/null || true
  echo "" >&2
  echo "--- Client 日志（最后 50 行）---" >&2
  tail -n 50 "$TMPDIR/client.log" 2>/dev/null || true
  exit 1
fi

echo "LinuxSmokeTest-e2e-deploy: ok"
