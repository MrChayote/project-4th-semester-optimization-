extends RigidBody3D
#van
@export var force : float = 20.0
var detected_bodies = {}  # Diccionario para rastrear objetos

func _ready():
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

@warning_ignore("unused_parameter")
func _physics_process(delta):
	apply_central_force(Vector3(0, 0, force))

func _on_body_entered(body):
	if body.collision_layer & (1 << 3):
		# Usamos el ID único de la instancia como clave
		var body_id = body.get_instance_id()
		
		if not detected_bodies.has(body_id):
			detected_bodies[body_id] = true  # Marcar como detectado
			var new_position = global_position
			new_position.y += 0.15
			global_position = new_position
			print("Objeto único detectado en capa 4")
