# Middle layer between State and every concrete player state (Idle, Walking, etc.).
# Exists to avoid repeating the same boilerplate in every state file.
class_name PlayerState 
extends State

# Typed reference to the Player node, cleaner than casting parent every time.
var player: Player

func _ready() -> void:
	# Player scene may not be fully initialized when child nodes fire _ready().
	# Waiting ensures player is never null on the first frame.
	await owner.ready
	player = owner as Player
	# If this state is used outside the Player scene, fail immediately with a clear message
	assert(player != null, "PlayerState must be used inside the Player scene.")
