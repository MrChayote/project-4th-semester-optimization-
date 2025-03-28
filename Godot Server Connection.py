import socket
import json

class GodotPhysicsServer:
    def __init__(self, host='127.0.0.1', port=9090):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.connect((host, port))
    
    def send_command(self, command, **kwargs):
        data = {"comando": command, **kwargs}
        self.sock.sendall(json.dumps(data).encode() + b'\n')
    
    def load_scene(self, scene_path):
        self.send_command("cargar_escena", ruta=scene_path)
    
    def move_object(self, node_name, transform_dict):
        self.send_command("mover_objeto", nombre=node_name, transform=transform_dict)
    
    def simulate(self, steps):
        self.send_command("simular", pasos=steps)
    
    def export_scene(self):
        self.send_command("exportar_escena")
        return json.loads(self.sock.recv(65536).decode())

if __name__ == "__main__":
    sim = GodotPhysicsServer()
    sim.load_scene("res://entorno.tscn")
    print("Escena cargada correctamente.")
