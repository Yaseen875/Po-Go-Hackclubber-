extends CharacterBody2D

signal fully_sunk   # emitted once, the instant he bottoms out in the slime
signal unstuck      # emitted once, the instant he jumps back out after being fully sunk

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var double_jump: Area2D = $DoubleJump

@export var air_move_speed: float = 300.0
@export var jump_velocity: float = -400.0

@export var sink_delay: float = 2.0      # seconds standing still before he starts sinking
@export var sink_speed: float = 20.0     # how fast he sinks into the slime ground (world px/sec)
@export var max_sink_depth: float = 12.0 # how far he can sink, in world pixels

var idle_timer: float = 0.0
var sink_depth: float = 0.0
var just_jumped: bool = false
var is_fully_sunk: bool = false


func _physics_process(delta: float) -> void:
	just_jumped = false

	if not is_on_floor():
		# Add the gravity.
		velocity += get_gravity() * delta
		# Steer mid-air only — zero horizontal motion while grounded.
		var direction := Input.get_axis("ui_left", "ui_right")
		velocity.x = direction * air_move_speed
		if direction != 0:
			animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = 0
		# Literal pogo stick: hold the jump button and he keeps relaunching on every touchdown.
		if Input.is_action_pressed("ui_accept"):
			launch_jump()

	# Mid-air only: bounce off a slime's weak point (no ground-based double jump).
	if not is_on_floor() and Input.is_action_just_pressed("ui_accept"):
		var hit_monster := false
		for area in double_jump.get_overlapping_areas():
			if area.owner and area.owner.is_in_group("monster"):
				hit_monster = true
				if area.owner.has_method("take_damage"):
					area.owner.take_damage()
				break
		if hit_monster:
			launch_jump()

	handle_sinking(delta)
	update_animation()
	move_and_slide()


func launch_jump() -> void:
	velocity.y = jump_velocity
	just_jumped = true
	# Pop straight back out of the slime the instant he jumps.
	sink_depth = 0.0
	idle_timer = 0.0
	if is_fully_sunk:
		is_fully_sunk = false
		unstuck.emit()


func handle_sinking(delta: float) -> void:
	if is_on_floor() and not just_jumped:
		idle_timer += delta
		if idle_timer >= sink_delay:
			sink_depth = min(sink_depth + sink_speed * delta, max_sink_depth)
			if sink_depth >= max_sink_depth and not is_fully_sunk:
				is_fully_sunk = true
				fully_sunk.emit()
	else:
		idle_timer = 0.0
		sink_depth = 0.0
	# Global position ignores the Player node's own scale (it's scaled 0.025 in
	# main.tscn), so this moves by real screen pixels instead of a near-zero
	# fraction of a local-space offset.
	animated_sprite_2d.global_position.y = global_position.y + sink_depth


func is_sinking() -> bool:
	# True the moment he starts sinking, even partway down.
	return sink_depth > 0.0


func update_animation() -> void:
	# No dedicated jump/fall frames exist yet in player.tscn, so this uses what's
	# actually there. Add "jump"/"fall" animations to AnimatedSprite2D and swap
	# the play() calls below in if you want distinct ones.
	if is_on_floor():
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("walk")
