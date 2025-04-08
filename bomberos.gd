extends RigidBody3D
# LOS BOMBEROS

@export var force : float = 24.0
var detected_bodies = {}  # Diccionario para rastrear objetos
var completedtest = false  # Variable para indicar si se completó la prueba
var fallido= false

func _ready():
	await get_tree().create_timer(1.0).timeout
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

@warning_ignore("unused_parameter")
func _physics_process(delta):
	apply_central_force(Vector3(0, 0, force))
	
func _on_body_entered(body):
	# Verificar si el cuerpo colisionado está en la máscara 8
	if global_transform.origin.y > 4.5 :
		if body.collision_layer & (1 << 7):  # (1 << 7) representa la máscara 8
			completedtest = true
			#print("¡El carrito chocó con el objetivo!")
	if global_transform.origin.z > 43 || global_transform.origin.x < -2 || global_transform.origin.x > 3 || global_transform.origin.y < 2:
		fallido = true
		#print(fallido)
		#print(completedtest)
		#print(global_transform.origin)
		#get_tree().paused = true
		
	elif body.collision_layer & (1 << 3):  # Mantenemos la detección de la capa 4 también
		# Usamos el ID único de la instancia como clave
		var body_id = body.get_instance_id()
		
		if not detected_bodies.has(body_id):
			detected_bodies[body_id] = true  # Marcar como detectado
			var new_position = global_position
			new_position.y += 0.15
			global_position = new_position
