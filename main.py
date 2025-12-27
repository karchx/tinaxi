import socket
import json

client_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client_socket.connect(('localhost', 9999))
# client_socket.send('SET projects { "title": "p1", "url": "https://github.com/karchx" }'.encode())
# data = client_socket.recv(1024).decode()
# print(f'Server response: {data}')
client_socket.send('GET projects'.encode())
data = client_socket.recv(1024).decode()
data_json = json.loads(data)
print(data_json)
client_socket.close()
