extends Control

const escena = preload("res://entorno.tscn")
var individuos: Array = []   # Almacenará la población actual de individuos
var cantidad_individuos: int = 10
var individuo_en_prueba: Dictionary = {}   # Individuo actual en evaluación
var mejores_hijos: Array = []   # Almacena los mejores individuos de una generación
var mejor_primera_generacion: Dictionary = {} # Almacena el mejor individuo de la primera generación

# Rangos para la posición aleatoria
var pos_min := Vector3(0, 3.5, 0)
var pos_max := Vector3(3.8, 4.5, 7.7)

# Variables para el algoritmo evolutivo
var cantidad_generaciones: int = 600
var generacion_actual: int = 0
var tasa_mutacion_base: float = 0.1
var tasa_mutacion_actual: float = tasa_mutacion_base
var elite_size: int = 2
var tiempo_maximo_prueba: float = 5.0 # Tiempo fijo para la prueba en segundos

func _ready() -> void:
	# Crear la población inicial de individuos
	for i in range(cantidad_individuos):
		var individuo = _crear_individuo_aleatorio(i)
		individuos.append(individuo)

	# Iniciar el bucle evolutivo
	for generacion in range(cantidad_generaciones):
		generacion_actual = generacion + 1
		print("\n--------------------- GENERACIÓN:", generacion_actual, "---------------------")

		# Evaluar la población actual
		await _evaluar_poblacion()

		# Clasificar los individuos
		clasificar_mejores_hijos()
		if mejores_hijos.size() > 0:
			for i in range(mejores_hijos.size()):
				var el_mejor_de_la_generacion = mejores_hijos[i]
				print("Mejor individuo de la generación", generacion_actual, ": ID =", el_mejor_de_la_generacion["id"], ", Prueba completada =", el_mejor_de_la_generacion["prueba_completada"], ", Cantidad de piezas =", el_mejor_de_la_generacion["cantidad_piezas"])

			# Guardar el mejor de la primera generación
			if generacion_actual == 1 and not mejor_primera_generacion:
				mejor_primera_generacion = mejores_hijos[0].duplicate(true)
				print("Mejor individuo de la primera generación guardado: ID =", mejor_primera_generacion["id"], ", Piezas =", mejor_primera_generacion["cantidad_piezas"])

		# Ajustar la tasa de mutación
		var individuos_exitosos = 0
		for individuo in individuos:
			if individuo["prueba_completada"]:
				individuos_exitosos += 1

		if individuos_exitosos < cantidad_individuos / 3:
			tasa_mutacion_actual = min(tasa_mutacion_base * 2, 0.5)
			print("Pocos individuos superaron la prueba. Aumentando la tasa de mutación a:", tasa_mutacion_actual)
		else:
			tasa_mutacion_actual = tasa_mutacion_base

		# Crear la nueva generación
		var nueva_poblacion = _crear_nueva_generacion(mejores_hijos)
		individuos = nueva_poblacion

	print("\n--------------------- FIN DEL ALGORITMO EVOLUTIVO ---------------------")
	if mejores_hijos.size() > 0:
		var el_mejor_final = mejores_hijos[0]
		print("El mejor individuo de la última generación: ID =", el_mejor_final["id"], ", Prueba completada =", el_mejor_final["prueba_completada"], ", Cantidad de piezas =", el_mejor_final["cantidad_piezas"])
		_visualizar_mejores_individuos(mejor_primera_generacion, el_mejor_final)
	else:
		print("No se encontraron individuos.")

func _crear_individuo_aleatorio(id: int) -> Dictionary:
	var instancia_temporal = escena.instantiate()
	var parent_node = instancia_temporal.get_node("piezas")
	if parent_node == null:
		push_error("No se encontró el nodo 'piezas' en la escena")
		return {}

	var individuo = {
		"id": id,
		"piezaName": parent_node.name,
		"children_data": [],
		"cantidad_piezas": 0,
		"prueba_completada": false
	}
	_inicializar_datos_aleatorios(parent_node, individuo)
	instancia_temporal.queue_free()
	return individuo

func _inicializar_datos_aleatorios(parent: Node, individuo: Dictionary) -> void:
	var conteo = 0
	for child in parent.get_children():
		if child is RigidBody3D:
			var probabilidad_activo_base = 0.2
			var factor_altura = clamp(1.0 - (child.position.y / pos_max.y), 0.2, 1.0)
			var esta_activo = randf() < probabilidad_activo_base * factor_altura;
			var posicion_final = child.position
			var rotacion_final = child.rotation

			var pieza_es_plana = child.name.begins_with("plano") # Asumimos que los nombres de los planos empiezan con "plano"
			var pos_min_pieza: Vector3
			var pos_max_pieza: Vector3

			if pieza_es_plana:
				pos_min_pieza = Vector3(0, 3.5, 0)
				pos_max_pieza = Vector3(3.8, 4.5, 7.7)
			else: # Asumimos que el resto son "bloques"
				pos_min_pieza = Vector3(0, 0, 0)
				pos_max_pieza = Vector3(0, 3.4, 7.7)

			if esta_activo:
				posicion_final = Vector3(
					randf_range(pos_min_pieza.x, pos_max_pieza.x),
					randf_range(pos_min_pieza.y, pos_max_pieza.y),
					randf_range(pos_min_pieza.z, pos_max_pieza.z)
				)
				var rotacion_y = deg_to_rad(float(randi_range(0, 3)) * 90.0)
				rotacion_final = Vector3(0, rotacion_y, 0)
				conteo += 1

			individuo["children_data"].append({
				"name": child.name,
				"activo": esta_activo,
				"position": posicion_final,
				"rotation": rotacion_final,
				"linear_velocity": child.linear_velocity,
				"angular_velocity": child.angular_velocity
			})

	individuo["cantidad_piezas"] = conteo

func _evaluar_poblacion() -> void:
	for i in range(individuos.size()):
		var instancia_visual = escena.instantiate()
		var parent_node_visual = instancia_visual.get_node("piezas")
		if parent_node_visual == null:
			push_error("No se encontró el nodo 'piezas' en la escena para visualización")
			instancia_visual.queue_free()
			continue

		individuo_en_prueba = individuos[i]
		aplicar_posiciones_visual(individuo_en_prueba, parent_node_visual)
		add_child(instancia_visual)

		# Ejecutar la prueba
		await pruebas_visual(individuo_en_prueba, instancia_visual)

		instancia_visual.queue_free()

func aplicar_posiciones_visual(individuo: Dictionary, parent_node: Node) -> void:
	if parent_node == null:
		push_error("No se encontró el nodo 'piezas' en la escena para aplicar posiciones")
		return

	for data in individuo["children_data"]:
		if parent_node.has_node(NodePath(data["name"])):
			var child = parent_node.get_node(NodePath(data["name"]))
			if child is RigidBody3D:
				child.position = data["position"]
				child.rotation = data["rotation"]
				child.linear_velocity = data["linear_velocity"]
				child.angular_velocity = data["angular_velocity"]

func pruebas_visual(individuo: Dictionary, instancia_prueba: Node) -> void:
	if not instancia_prueba or not instancia_prueba.has_node("Bomberos"):
		print("No se encontró el nodo Bomberos en la instancia de prueba")
		return

	var bomberos = instancia_prueba.get_node("Bomberos")
	bomberos.completedtest = false
	bomberos.fallido = false

	var terminado = false
	var tiempo_inicio = Time.get_ticks_msec()
	var tiempo_maximo_prueba_ms = tiempo_maximo_prueba * 1000

	while not terminado:
		if not is_instance_valid(bomberos):
			terminado = true
			continue

		if bomberos.completedtest:
			terminado = true
			individuo["prueba_completada"] = true
			continue

		if bomberos.fallido:
			terminado = true
			individuo["prueba_completada"] = false
			continue

		if Time.get_ticks_msec() - tiempo_inicio > tiempo_maximo_prueba_ms:
			terminado = true
			individuo["prueba_completada"] = false
			continue

		await get_tree().process_frame

func clasificar_mejores_hijos() -> void:
	mejores_hijos = individuos.duplicate(true)
	mejores_hijos.sort_custom(func(a, b):
		if a["prueba_completada"] and not b["prueba_completada"]:
			return true
		elif not a["prueba_completada"] and b["prueba_completada"]:
			return false
		return a["cantidad_piezas"] > b["cantidad_piezas"]
	)

func _seleccionar_padres(poblacion: Array) -> Array:
	var padres: Array = []
	for i in range(min(elite_size, poblacion.size())):
		padres.append(poblacion[i])
	return padres

func _cruzar(padre1: Dictionary, padre2: Dictionary, nuevo_id: int) -> Dictionary:
	var hijo = {
		"id": nuevo_id,
		"piezaName": padre1["piezaName"],
		"children_data": [],
		"cantidad_piezas": 0,
		"prueba_completada": false
	}
	var conteo_piezas_hijo = 0

	for i in range(padre1["children_data"].size()):
		var data_padre1 = padre1["children_data"][i]
		var data_padre2 = padre2["children_data"][i]
		var data_hijo = {
			"name": data_padre1["name"],
			"activo": (data_padre1["activo"] if randf() < 0.5 else data_padre2["activo"]),
			"position": (data_padre1["position"] if randf() < 0.5 else data_padre2["position"]),
			"rotation": (data_padre1["rotation"] if randf() < 0.5 else data_padre2["rotation"]),
			"linear_velocity": Vector3(), # Reiniciar velocidades
			"angular_velocity": Vector3() # Reiniciar velocidades
		}

		if data_hijo["activo"]:
			conteo_piezas_hijo += 1
		hijo["children_data"].append(data_hijo)

	hijo["cantidad_piezas"] = conteo_piezas_hijo
	return hijo

func _mutar(individuo: Dictionary, tasa_mutacion: float) -> void:
	for data in individuo["children_data"]:
		if randf() < tasa_mutacion:
			data["activo"] = not data["activo"]

		if data["activo"]:
			var pieza_es_plana = data["name"].begins_with("plano")
			var pos_min_pieza: Vector3
			var pos_max_pieza: Vector3

			if pieza_es_plana:
				pos_min_pieza = Vector3(0, 3.5, 0)
				pos_max_pieza = Vector3(3.8, 4.5, 7.7)
			else:
				pos_min_pieza = Vector3(0, 0, 0)
				pos_max_pieza = Vector3(3.8, 3.4, 7.7)

			if randf() < tasa_mutacion:
				data["position"] = Vector3(
					randf_range(pos_min_pieza.x, pos_max_pieza.x),
					randf_range(pos_min_pieza.y, pos_max_pieza.y),
					randf_range(pos_min_pieza.z, pos_max_pieza.z)
				)
			if randf() < tasa_mutacion:
				var rotacion_actual_y_rad = data["rotation"].y
				var rotacion_actual_y_deg = rad_to_deg(rotacion_actual_y_rad)
				var cambio = [-90, 0, 90][randi_range(0, 2)]
				var nueva_rotacion_y_deg = fmod(rotacion_actual_y_deg + cambio, 360)
				data["rotation"] = Vector3(0, deg_to_rad(nueva_rotacion_y_deg), 0)

	var conteo = 0
	for data in individuo["children_data"]:
		if data["activo"]:
			conteo += 1
	individuo["cantidad_piezas"] = conteo

func _crear_nueva_generacion(individuos_generacion_anterior: Array) -> Array:
	var nueva_generacion: Array = []
	var cantidad_elite = int(cantidad_individuos / 2)

	# 1. Seleccionar los mejores individuos (asumiendo que 'individuos_generacion_anterior' ya está ordenada por rendimiento)
	var elite = individuos_generacion_anterior.slice(0, cantidad_elite)

	# 2. Cruzar los mejores individuos por parejas y generar dos hijos por pareja
	for i in range(0, elite.size(), 2):
		if i + 1 < elite.size():
			var padre1 = elite[i]
			var padre2 = elite[i + 1]

			# Generar dos hijos por pareja
			var hijo1 = _cruzar(padre1, padre2, individuos.size() + nueva_generacion.size())
			_mutar(hijo1, tasa_mutacion_actual)
			nueva_generacion.append(hijo1)

			var hijo2 = _cruzar(padre2, padre1, individuos.size() + nueva_generacion.size())
			_mutar(hijo2, tasa_mutacion_actual)
			nueva_generacion.append(hijo2)
		else:
			# Si hay un número impar de élite, simplemente añade el último individuo a la nueva generación (como un "clon" con posible mutación)
			var clon = elite[i].duplicate(true)
			clon["id"] = individuos.size() + nueva_generacion.size()
			_mutar(clon, tasa_mutacion_actual)
			nueva_generacion.append(clon)

	# Asegurarse de que la nueva generación tenga el tamaño deseado
	while nueva_generacion.size() < cantidad_individuos:
		# Si por alguna razón no se generaron suficientes hijos, podemos añadir algunos cruzamientos aleatorios de la élite
		var indice_padre1 = randi() % elite.size()
		var indice_padre2 = randi() % elite.size()
		var padre1_extra = elite[indice_padre1]
		var padre2_extra = elite[indice_padre2]
		var hijo_extra = _cruzar(padre1_extra, padre2_extra, individuos.size() + nueva_generacion.size())
		_mutar(hijo_extra, tasa_mutacion_actual)
		nueva_generacion.append(hijo_extra)

	# Imprimir la ubicación de las primeras 5 piezas de cada nuevo individuo (para debugging)
	#print("\n--- NUEVA GENERACIÓN ---")
	#for individuo in nueva_generacion:
		#print("Individuo ID:", individuo["id"])
		#for j in range(min(5, individuo["children_data"].size())):
		#	var pieza = individuo["children_data"][j]
		#	print("  Pieza:", pieza["name"], "- Posición:", pieza["position"])

	return nueva_generacion

func _visualizar_mejores_individuos(mejor_primera_gen: Dictionary, mejor_ultima_gen: Dictionary) -> void:
	if mejor_primera_gen.size() > 0:
		var instancia_primera_gen = escena.instantiate()
		var piezas_primera_gen = instancia_primera_gen.get_node("piezas")
		if piezas_primera_gen:
			aplicar_posiciones_visual(mejor_primera_gen, piezas_primera_gen)
			add_child(instancia_primera_gen)
			instancia_primera_gen.name = "Mejor_Generacion_1_ID_" + str(mejor_primera_gen["id"])
			print("\nVisualizando el mejor individuo de la primera generación: ID =", mejor_primera_gen["id"], ", Piezas =", mejor_primera_gen["cantidad_piezas"])
		else:
			instancia_primera_gen.queue_free()
			print("No se encontró el nodo 'piezas' en la instancia para el mejor de la primera generación.")

	if mejor_ultima_gen.size() > 0:
		var instancia_ultima_gen = escena.instantiate()
		var piezas_ultima_gen = instancia_ultima_gen.get_node("piezas")
		if piezas_ultima_gen:
			aplicar_posiciones_visual(mejor_ultima_gen, piezas_ultima_gen)
			add_child(instancia_ultima_gen)
			instancia_ultima_gen.name = "Mejor_Ultima_Generacion_ID_" + str(mejor_ultima_gen["id"])
			print("Visualizando el mejor individuo de la última generación: ID =", mejor_ultima_gen["id"], ", Piezas =", mejor_ultima_gen["cantidad_piezas"])
		else:
			instancia_ultima_gen.queue_free()
			print("No se encontró el nodo 'piezas' en la instancia para el mejor de la última generación.")
