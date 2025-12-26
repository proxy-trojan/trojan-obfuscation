import socket
import sys

def test_udp_forwarding(server_ip, server_port):
    print(f"Testing UDP forwarding to {server_ip}:{server_port}")
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.settimeout(2)
    
    # Simple Trojan UDP packet structure (assumed) or just generic data to trigger processing
    # Note: Real Trojan UDP packets need authentication/specific header. 
    # This test is just to see if the service crashes or accepts packets.
    # Logic: 
    # 1. Send garbage. 
    # 2. If service crashes -> Fail.
    # 3. If service logs error -> Pass (logic works).
    
    msg = b"test_data_packet_1"
    try:
        sock.sendto(msg, (server_ip, int(server_port)))
        print("Packet 1 sent.")
        
        import time
        time.sleep(0.5)
        
        msg2 = b"test_data_packet_2"
        sock.sendto(msg2, (server_ip, int(server_port)))
        print("Packet 2 sent.")
        # We might not get a response if auth fails, which is expected for garbage data.
        # But we want to ensure the server doesn't segfault due to our map changes.
    except Exception as e:
        print(f"Error sending packet: {e}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 udp_test.py <ip> <port>")
        sys.exit(1)
    test_udp_forwarding(sys.argv[1], sys.argv[2])
