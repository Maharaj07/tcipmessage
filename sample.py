# Python 3 — Echo server, binds 0.0.0.0 so emulator can reach it
import socket, threading
HOST = '0.0.0.0'
PORT = 9000
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind((HOST, PORT))
s.listen(5)
print(f"Listening on {HOST}:{PORT}")
def handle(conn, addr):
    print("Conn from", addr)
    try:
        while True:
            data = conn.recv(4096)
            if not data: break
            print("RX:", data.decode(errors='replace'))
            conn.sendall(data)  # echo back
    finally:
        conn.close()
while True:
    conn, addr = s.accept()
    threading.Thread(target=handle, args=(conn, addr), daemon=True).start()
PY
