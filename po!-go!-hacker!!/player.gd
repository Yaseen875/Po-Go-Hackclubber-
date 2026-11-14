extends CharacterBody2D

signal fully_sunk
signal unstuck

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var double_jump: Area2D = $DoubleJump

@export var air_move_speed: float = 300.0
@export var jump_velocity: float = -400.0

@export var sink_delay: float = 0.5
@export var sink_speed: float = 20.0
@export var max_sink_depth: float = 12.0

@export var knockback_speed: float = 350.0
@export var knockback_duration: float = 0.25

var idle_timer: float = 0.0
var sink_depth: float = 0.0
var just_jumped: bool = false
var is_fully_sunk: bool = false
var knockback_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	double_jump.area_entered.connect(_on_double_jump_area_entered)

func _physics_process(delta: float) -> void:
	just_jumped = false

	if knockback_timer > 0.0:
		knockback_timer -= delta
		velocity += get_gravity() * delta
	elif not is_on_floor():
		velocity += get_gravity() * delta
		var direction := Input.get_axis("ui_left", "ui_right")
		velocity.x = direction * air_move_speed
		if direction != 0:
			animated_sprite_2d.flip_h = direction < 0
	else:
		velocity.x = 0
		if Input.is_action_pressed("JUMP"):
			launch_jump()
	if is_fully_sunk:
		get_tree().call_deferred("reload_current_scene")
	handle_sinking(delta)
	update_animation()
	move_and_slide()
	handle_monster_collisions()


func launch_jump() -> void:
	velocity.y = jump_velocity
	just_jumped = true
	sink_depth = 0.0
	idle_timer = 0.0
	if is_fully_sunk:
		is_fully_sunk = false
		unstuck.emit()


func handle_sinking(delta: float) -> void:
	if is_on_floor() and not just_jumped and knockback_timer <= 0.0:
		idle_timer += delta
		if idle_timer >= sink_delay:
			sink_depth = min(sink_depth + sink_speed * delta, max_sink_depth)
			if sink_depth >= max_sink_depth and not is_fully_sunk:
				is_fully_sunk = true
				fully_sunk.emit()
	else:
		idle_timer = 0.0
		sink_depth = 0.0
	animated_sprite_2d.global_position.y = global_position.y + sink_depth


func is_sinking() -> bool:
	return sink_depth > 0.0


func update_animation() -> void:
	if is_on_floor():
		animated_sprite_2d.play("idle")
	else:
		animated_sprite_2d.play("walk")

func _on_double_jump_area_entered(area: Area2D) -> void:
	if velocity.y >= 0 and area.owner and area.owner.is_in_group("monster"):
		if area.owner.has_method("take_damage"):
			area.owner.take_damage()
		launch_jump()
	elif area.is_in_group("JUMP_BOOS"):
		velocity.y += jump_velocity

func handle_monster_collisions() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and collider.is_in_group("monster") and collision.get_normal().y > -0.5:
			get_tree().call_deferred("reload_current_scene")
			knockback_timer = knockback_duration
