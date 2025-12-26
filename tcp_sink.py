import socket
import time

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.bind(('127.0.0.1', 8080))
s.listen(1)
print("Listening on 8080...")
while True:
    conn, addr = s.accept()
    print(f"Accepted connection from {addr}")
    # Hold connection open
    time.sleep(5)
    conn.close()
