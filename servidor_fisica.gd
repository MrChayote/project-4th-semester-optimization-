extends Node3D

var server := TCPServer.new()
var client: StreamPeerTCP = null
var escena_simulacion: Node3D = null
var json_parser = JSON.new()

func _ready():
	if server.listen(9090) == OK:
		print("Servidor iniciado en el puerto 9090")
	else:
		printerr("Error al iniciar el servidor")

func _process(delta):
	if server.is_connection_available():
		client = server.take_connection()
		print("Cliente conectado: %s:%d" % [client.get_connected_host(), client.get_connected_port()])

	if client and client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		if client.get_available_bytes() > 0:
			var mensaje = client.get_utf8_string(client.get_available_bytes())
			if mensaje:
				procesar_mensaje(mensaje)

func procesar_mensaje(mensaje: String):
	var error = json_parser.parse(mensaje)
	if error != OK:
		printerr("Error en JSON: %s" % json_parser.get_error_message())
		return
	
	var datos = json_parser.get_data()
	match datos.get("comando"):
		"cargar_escena":
			cargar_escena(datos.get("ruta"))
		
		"mover_objeto":
			mover_objeto(
				datos.get("nombre"), 
				str_a_transform(datos.get("transform"))
			)
		
		"simular":
			simular(datos.get("pasos", 60))
		
		"exportar_escena":
			exportar_escena()
		
		_:
			printerr("Comando no reconocido")

func cargar_escena(ruta: String):
	if escena_simulacion:
		escena_simulacion.queue_free()
	
	var escena = load(ruta)
	if escena:
		escena_simulacion = escena.instantiate()
		add_child(escena_simulacion)
		print("Escena cargada: ", ruta)
	else:
		printerr("Error cargando escena: ", ruta)

func mover_objeto(nombre: String, transform: Transform3D):
	if not escena_simulacion:
		printerr("No hay escena cargada")
		return
	
	var nodo = escena_simulacion.get_node_or_null(NodePath(nombre))
	if nodo and nodo is Node3D:
		nodo.transform = transform
		print("Objeto movido: ", nombre)
	else:
		printerr("Objeto no encontrado: ", nombre)

func simular(pasos: int):
	if not escena_simulacion:
		printerr("No hay escena cargada")
		return
	
	for i in pasos:
		get_tree().root.physics_pipeline.step()
		await get_tree().process_frame
	
	print("Simulación completada: %d pasos" % pasos)

func exportar_escena():
	if not escena_simulacion:
		printerr("No hay escena cargada")
		return
	
	var datos = {
		"nodos": [],
		"rigidbodies": []
	}
	
	for nodo in escena_simulacion.get_children():
		var info_nodo = {
			"nombre": nodo.name,
			"tipo": nodo.get_class(),
			"transform": transform_a_str(nodo.transform)
		}
		
		if nodo is RigidBody3D:
			info_nodo["masa"] = nodo.mass
			info_nodo["colisiones"] = obtener_colisiones(nodo)
			datos["rigidbodies"].append(info_nodo)
		
		datos["nodos"].append(info_nodo)
	
	var json_str = JSON.stringify(datos)
	client.put_data(json_str.to_utf8_buffer())
	print("Escena exportada a JSON")

func obtener_colisiones(nodo: RigidBody3D) -> Array:
	var colisiones = []
	for hijo in nodo.get_children():
		if hijo is CollisionShape3D:
			var shape_info = {
				"tipo": hijo.shape.get_class(),
				"posicion": transform_a_str(hijo.transform)
			}
			
			if hijo.shape is BoxShape3D:
				shape_info["tamaño"] = {
					"x": hijo.shape.size.x,
					"y": hijo.shape.size.y,
					"z": hijo.shape.size.z
				}
			
			colisiones.append(shape_info)
	return colisiones

func transform_a_str(t: Transform3D) -> Dictionary:
	return {
		"basis_x": { "x": t.basis.x.x, "y": t.basis.x.y, "z": t.basis.x.z },
		"basis_y": { "x": t.basis.y.x, "y": t.basis.y.y, "z": t.basis.y.z },
		"basis_z": { "x": t.basis.z.x, "y": t.basis.z.y, "z": t.basis.z.z },
		"origin": { "x": t.origin.x, "y": t.origin.y, "z": t.origin.z }
	}

func str_a_transform(d: Dictionary) -> Transform3D:
	return Transform3D(
		Basis(
			Vector3(d["basis_x"]["x"], d["basis_x"]["y"], d["basis_x"]["z"]),
			Vector3(d["basis_y"]["x"], d["basis_y"]["y"], d["basis_y"]["z"]),
			Vector3(d["basis_z"]["x"], d["basis_z"]["y"], d["basis_z"]["z"])
		),
		Vector3(d["origin"]["x"], d["origin"]["y"], d["origin"]["z"])
	)
