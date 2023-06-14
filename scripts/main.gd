extends Node

var bounding_box_size := 2.0
var bb_extent := bounding_box_size / 2.0

var cell_resolution := 7
var grid_resolution := cell_resolution + 1
var cell_size := bounding_box_size / grid_resolution
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
	for x in grid_resolution:
		for y in grid_resolution:
			for z in grid_resolution:
				var position := get_grid_point_position_3i(x, y, z)
				var value := get_noise_3dv(position)
				var grid_point := Vector4(position.x, position.y, position.z, value)
				grid_points.append(grid_point)
	# Create vertices
	for x in cell_resolution:
		for y in cell_resolution:
			for z in cell_resolution:
				# Check that vertex is within cell with sign change
				# Get grid points of cell
				var cell_grid_points := [
					get_grid_point(x,   y,   z  ),
					get_grid_point(x+1, y,   z  ),
					get_grid_point(x,   y+1, z  ),
					get_grid_point(x+1, y+1, z  ),
					get_grid_point(x,   y,   z+1),
					get_grid_point(x+1, y,   z+1),
					get_grid_point(x,   y+1, z+1),
					get_grid_point(x+1, y+1, z+1)
				]
				# Check for sign change
				var inside := true
				var outside := true
				for grid_point in cell_grid_points:
					if grid_point.w > 0.0:
						inside = false
					if grid_point.w <= 0.0:
						outside = false
				if not inside and not outside:
					# Create vertex
					var position := get_vertex_position_3i(x, y ,z)
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


func get_grid_point(x: int, y: int, z: int) -> Vector4:
	return grid_points[x * grid_resolution ** 2 + y * grid_resolution + z]


func get_grid_point_position_3i(x: int, y: int, z: int) -> Vector3:
	return Vector3(
		-bb_extent + cell_offset + (cell_size * x),
		-bb_extent + cell_offset + (cell_size * y),
		-bb_extent + cell_offset + (cell_size * z)
	)


func get_vertex_position_3i(x: int, y: int, z: int) -> Vector3:
	return Vector3(
		-bb_extent + cell_size + (cell_size * x),
		-bb_extent + cell_size + (cell_size * y),
		-bb_extent + cell_size + (cell_size * z)
	)


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
