extends MeshInstance2D

export var is_static = false

var speed = Vector2.ZERO
var angular_speed = 0
var mass : float = 1.0
var moment_of_inertia = 1e2

var last_speed = Vector2.ZERO
var last_angular_speed = 0
var last_position : Vector2
var last_rotation_degrees = 0

var offsets

var is_collided = false;

var force : Vector2 = Vector2.ZERO
var torque = 0
var delta = 0

var g = 60.0

var EPS = 1e-3

func get_point(i, p):
	return p + offsets[i].rotated(deg2rad(rotation_degrees))
	
func get_points(p):
	var result = []
	for i in range(4):
		result.append(p + offsets[i].rotated(deg2rad(rotation_degrees)))
	return result

func get_local_points():
	var t1 = Vector2(-scale.x, scale.y)
	var t2 = Vector2(scale.x, -scale.y)
	return [scale, -scale, t1, t2]

func is_inside(p : Vector2):
	var diff : Vector2 = ((p - position).rotated(-rotation_degrees * PI / 180) / scale).abs()
	return max(diff.x, diff.y) < 1
	
func closest_edge_normal_vector(p: Vector2, dir):
	var p_local = ((p - position).rotated(-rotation_degrees * PI / 180) / scale)
	var normals = [
		Vector2.UP,
		Vector2.RIGHT,
		-Vector2.UP,
		-Vector2.RIGHT
	]
	var dists = [
		p_local.y + 1,
		1 - p_local.x,
		1 - p_local.y,
		p_local.x + 1,
	]
	var min_dist = 3
	var min_normal = Vector2.UP
	for i in range(4):
		if dists[i] < min_dist && normals[i].dot(dir) <= 0:
			min_normal = normals[i]
			min_dist = dists[i]
	return min_normal.rotated(rotation_degrees * PI / 180).normalized()
	
func closest_edge_dist_vector(p: Vector2, n):
	var p_local = ((p - position).rotated(-rotation_degrees * PI / 180) / scale)
	var d = min(1 - abs(p_local.x), 1 - abs(p_local.y)) 
	var dist = d * (n * scale).length()
	return dist;
	
func impulse_response(p, n, effector):
	var r = p - position
	var local_speed = speed + Vector2(r.y * -angular_speed, r.x * angular_speed)
	var j = -local_speed.dot(n) / (1 / mass + r.cross(n) * r.cross(n) / moment_of_inertia)
	speed += j * n / mass
	angular_speed += r.cross(j * n) / moment_of_inertia

func collide():
	for node in owner.get_children():
		if node is MeshInstance2D and node != self:
			var mesh : MeshInstance2D = node
			for i in range(4):
				var p = get_point(i, position)
				if node.is_inside(p):
					
					# body penetrates static object
					if not is_static:
						var dir = speed.rotated(-node.rotation_degrees * PI / 180).normalized()
						var n = node.closest_edge_normal_vector(p, dir)
						impulse_response(p, n, node)
						
						var d = closest_edge_dist_vector(p, n) + EPS
						position += d * n;

					# static object penetrates body
					if not node.is_static:
						var dir = -node.speed.rotated(-node.rotation_degrees * PI / 180).normalized()
						var n = -node.closest_edge_normal_vector(p, dir)
						node.impulse_response(p, n, node)
						
						var d = node.closest_edge_dist_vector(p, n) + EPS
						node.position +=  d * n;
						
	return is_collided

# Called when the node enters the scene tree for the first time.
func _ready():
	last_position = position
	last_rotation_degrees = rotation_degrees
	offsets = [
		Vector2(-scale.x, scale.y), Vector2(scale.x, -scale.y), scale, -scale
	]

var accum = 0.0
var dt = 0.0008

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	accum += delta
	while accum >= dt:
		delta = dt
		
		collide()
		
		if is_static:
			return
		
		# Apply force
		var a = force / mass - g * Vector2.UP	
		speed += a * delta
		position += speed * delta
		
		# Apply torque
		var w = torque / moment_of_inertia
		angular_speed += w * delta
		rotate(angular_speed * delta)
		
		# Reset collision
		force = Vector2.ZERO
		torque = 0
		is_collided = false
		
		accum -= dt
