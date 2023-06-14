extends Node

var bounding_box_size := 2.0
var bb_extent := bounding_box_size / 2.0
var cell_resolution := 10
var cell_size := bounding_box_size / cell_resolution
var cell_offset := cell_size / 2.0

var grid_point_size := cell_size / 5.0
var vertex_size := cell_size / 5.0


@onready var node3d := $Node3D
@onready var multimesh : MultiMesh = $Node3D/MultiMeshInstance3D.get_multimesh()


var grid_points := []
var vertices := []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create grid points
	var bounds := Vector3(-bb_extent + cell_offset, bb_extent + cell_offset, cell_size)
	for x in bounds:
		for y in bounds:
			for z in bounds:
				var position := Vector3(x, y, z)
				var value := get_noise_3dv(position)
				var grid_point := Vector4(x, y, z, value)
				grid_points.append(grid_point)
	# Create vertices
	bounds = Vector3(-bb_extent + cell_size, bb_extent, cell_size)
	for x in bounds:
		for y in bounds:
			for z in bounds:
				var position := Vector3(x, y, z)
				vertices.append(position)
	# Draw grid points and vertices
	multimesh.set_instance_count(len(grid_points) + len(vertices))
	# Draw grid points
	var scale := Vector3.ONE * grid_point_size
	var transform := Transform3D().scaled(scale)
	for instance in len(grid_points):
		var grid_point : Vector4 = grid_points[instance]
		var position := Vector3(grid_point.x, grid_point.y, grid_point.z)
		var value : float = grid_point.w
		multimesh.set_instance_transform(instance, transform.translated(position))
		var color := get_noise_color_f(value)
		multimesh.set_instance_color(instance, color)
	# Draw vertices
	scale = Vector3.ONE * vertex_size
	transform = Transform3D().scaled(scale)
	for instance in range(len(grid_points), len(grid_points) + len(vertices)):
		var vertex : Vector3 = vertices[instance - len(grid_points)]
		multimesh.set_instance_transform(instance, transform.translated(vertex))
		multimesh.set_instance_color(instance, Color.RED)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass


func get_noise_3dv(v: Vector3) -> float:
	# Unit sphere
	if v.length() <= 1.0:
		return -1.0
	else:
		return 1.0


func get_noise_color_f(f: float) -> Color:
	if f >= 0.0:
		return Color.WHITE
	else:
		return Color.BLACK


func get_noise_color_3dv(v: Vector3) -> Color:
	return get_noise_color_f(get_noise_3dv(v))
