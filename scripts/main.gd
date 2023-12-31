extends Node


# Properties

var mouse_sensitivity := 0.002

var grid_resolution := 84

var bounding_box_size := float(grid_resolution)
var bb_extent := bounding_box_size / 2.0

var cell_resolution := grid_resolution - 1
var cell_size := bounding_box_size / grid_resolution
var cell_offset := cell_size / 2.0

var grid_point_and_vertex_size := cell_size / 5.0
var edge_width := grid_point_and_vertex_size / 2.0

var vertex_color := Color.RED
var edge_color := Color.BLUE

var show_grid_points := true
var show_vertices := true
var show_edges := true
var show_mesh := true
var interpolation := true
var show_normal_buffer := false

var zoom_step := cell_size / 5.0

var noise_scale := 3.0
var noise_frequency := 1.0


# Constants

const EDGE_INDICES := [
	[0, 1], [1, 3], [3, 2], [2, 0],
	[4, 5], [5, 7], [7, 6], [6, 4],
	[0, 4], [1, 5], [3, 7], [2, 6]
]

const HEXAGON_VERTICES := [
	Vector2(1.0, 0.0),
	Vector2(0.5, sqrt(3.0) / 2.0),
	Vector2(-0.5, sqrt(3.0) / 2.0),
	Vector2(-1.0, 0.0),
	Vector2(-0.5, -sqrt(3.0) / 2.0),
	Vector2(0.5, -sqrt(3.0) / 2.0)
]

const HEXAGON_INDICES := [
	0, 2, 1,
	0, 3, 2,
	0, 5, 3,
	5, 4, 3
]


# Node paths

@onready var node3d := $Node3D
@onready var mesh := $Node3D/Mesh
@onready var multimesh : MultiMesh = $Node3D/MultiMesh.get_multimesh()
@onready var edge_multimesh: MultiMesh = $Node3D/EdgeMultiMesh.get_multimesh()
@onready var camera_orbit_center := $Node3D/CameraOrbitCenter
@onready var camera := $Node3D/CameraOrbitCenter/Camera3D


# Variables

var grid_points := []
var vertices := []
var edges := []

var noise := FastNoiseLite.new()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	camera.position.z = bounding_box_size
	noise.set_frequency(noise_scale * noise_frequency / grid_resolution)
	build()
	draw()
	mesh.visible = show_mesh
	set_show_normal_buffer(show_normal_buffer)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass


func _input(event: InputEvent) -> void:
	# Camera movement
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var rel := (event as InputEventMouseMotion).relative
			var rotation_delta := Vector3(-rel.y, -rel.x, 0.0)
			camera_orbit_center.rotation += rotation_delta * mouse_sensitivity
	if event.is_action_pressed("zoom_in"):
		camera.position.z -= zoom_step
	if event.is_action_pressed("zoom_out"):
		camera.position.z += zoom_step
	# Generation controls
	var redraw := false
	if event.is_action_pressed("toggle_show_grid_points"):
		show_grid_points = !show_grid_points
		redraw = true
	if event.is_action_pressed("toggle_show_vertices"):
		show_vertices = !show_vertices
		redraw = true
	if event.is_action_pressed("toggle_show_edges"):
		show_edges = !show_edges
		redraw = true
	if event.is_action_pressed("toggle_show_mesh"):
		mesh.visible = !mesh.visible
	if event.is_action_pressed("toggle_interpolation"):
		interpolation = !interpolation
		build()
		redraw = true
	if event.is_action_pressed("toggle_show_normal_buffer"):
		show_normal_buffer = !show_normal_buffer
		set_show_normal_buffer(show_normal_buffer)
	if redraw:
		draw()


# Builds grid points, vertices, and edges
func build() -> void:
	var build_start_time = Time.get_ticks_msec()
	# Create grid points
	grid_points.clear()
	for x in grid_resolution:
		for y in grid_resolution:
			for z in grid_resolution:
				var position := get_grid_point_position_3i(x, y, z)
				var value := get_noise_3dv(position)
				var grid_point := Vector4(position.x, position.y, position.z, value)
				grid_points.append(grid_point)
	print("Create grid points time: " + str(Time.get_ticks_msec() - build_start_time) + "ms")
	# Create vertices and edges
	vertices.clear()
	edges.clear()
	var mesh_quad_indices := []
	for x in cell_resolution:
		for y in cell_resolution:
			for z in cell_resolution:
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
				# If vertex is within cell with sign change
				if not (inside or outside):
					# Find which edges of cell have sign change
					var cell_grid_edges := []
					for edge_index in [0, 3, 8]:
						var edge : Array = EDGE_INDICES[edge_index]
						var value_a : float = cell_grid_points[edge[0]].w
						var value_b : float = cell_grid_points[edge[1]].w
						var sign_a := signf(value_a)
						var sign_b := signf(value_b)
						cell_grid_edges.append([sign_a != sign_b, sign_a > sign_b])
					# If edge 0 has sign change
					if cell_grid_edges[0][0]:
						edges.append([Vector3i(x, y, z), Vector3i(x, y, z-1)])
						edges.append([Vector3i(x, y, z), Vector3i(x, y-1, z)])
						edges.append([Vector3i(x, y, z), Vector3i(x, y-1, z-1)])
						edges.append([Vector3i(x, y, z-1), Vector3i(x, y-1, z-1)])
						edges.append([Vector3i(x, y-1, z), Vector3i(x, y-1, z-1)])
						var quad_indices := [
							Vector3i(x, y, z),
							Vector3i(x, y-1, z-1),
							Vector3i(x, y-1, z),
							Vector3i(x, y, z),
							Vector3i(x, y, z-1),
							Vector3i(x, y-1, z-1)
						]
						if cell_grid_edges[0][1]:
							quad_indices.reverse()
						mesh_quad_indices.append(quad_indices)
					# If edge 3 has sign change
					if cell_grid_edges[1][0]:
						edges.append([Vector3i(x, y, z), Vector3i(x-1, y, z)])
						edges.append([Vector3i(x, y, z), Vector3i(x, y, z-1)])
						edges.append([Vector3i(x, y, z), Vector3i(x-1, y, z-1)])
						edges.append([Vector3i(x-1, y, z), Vector3i(x-1, y, z-1)])
						edges.append([Vector3i(x, y, z-1), Vector3i(x-1, y, z-1)])
						var quad_indices := [
							Vector3i(x, y, z),
							Vector3i(x-1, y, z-1),
							Vector3i(x, y, z-1),
							Vector3i(x, y, z),
							Vector3i(x-1, y, z),
							Vector3i(x-1, y, z-1)
						]
						if not cell_grid_edges[1][1]:
							quad_indices.reverse()
						mesh_quad_indices.append(quad_indices)
					# If edge 8 has sign change
					if cell_grid_edges[2][0]:
						edges.append([Vector3i(x, y, z), Vector3i(x, y-1, z)])
						edges.append([Vector3i(x, y, z), Vector3i(x-1, y, z)])
						edges.append([Vector3i(x, y, z), Vector3i(x-1, y-1, z)])
						edges.append([Vector3i(x, y-1, z), Vector3i(x-1, y-1, z)])
						edges.append([Vector3i(x-1, y, z), Vector3i(x-1, y-1, z)])
						var quad_indices := [
							Vector3i(x, y, z),
							Vector3i(x-1, y-1, z),
							Vector3i(x-1, y, z),
							Vector3i(x, y, z),
							Vector3i(x, y-1, z),
							Vector3i(x-1, y-1, z)
						]
						if cell_grid_edges[2][1]:
							quad_indices.reverse()
						mesh_quad_indices.append(quad_indices)
					# Approximate position of zero value along edges with sign change
					var cell_grid_edge_zeroes := []
					for edge_index in EDGE_INDICES:
						var value_a : float = cell_grid_points[edge_index[0]].w
						var value_b : float = cell_grid_points[edge_index[1]].w
						cell_grid_edge_zeroes.append(value_a / (value_a - value_b))
					var cell_grid_edge_zero_positions := []
					for i in 12:
						var cell_grid_edge_zero : float = cell_grid_edge_zeroes[i]
						if 0.0 <= cell_grid_edge_zero and cell_grid_edge_zero <= 1.0:
							var edge_index_a : int = EDGE_INDICES[i][0]
							var edge_index_b : int = EDGE_INDICES[i][1]
							var point_a := v4_to_v3(cell_grid_points[edge_index_a])
							var point_b := v4_to_v3(cell_grid_points[edge_index_b])
							var point := point_a.lerp(point_b, cell_grid_edge_zero)
							cell_grid_edge_zero_positions.append(point)
					# Average zero value positions
					var position := Vector3.ZERO
					for cell_grid_edge_zero_position in cell_grid_edge_zero_positions:
						position += cell_grid_edge_zero_position
					position /= len(cell_grid_edge_zero_positions)
#					# Create vertex
					if not interpolation:
						position = get_vertex_position_3i(x, y ,z)
					var vertex := Vector4(position.x, position.y, position.z, true)
					vertices.append(vertex)
				else:
					# Create hidden vertex
					var position := get_vertex_position_3i(x, y ,z)
					var vertex := Vector4(position.x, position.y, position.z, false)
					vertices.append(vertex)
	# Create mesh
	var start_time = Time.get_ticks_msec()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for quad_indices in mesh_quad_indices:
		for index in quad_indices:
			var vertex : Vector4 = vertices[get_vertex_index_3dvi(index)]
			var position := v4_to_v3(vertex)
			st.add_vertex(position)
	st.index()
	st.generate_normals()
	mesh.set_mesh(st.commit())
	print("Create mesh time: " + str(Time.get_ticks_msec() - start_time) + "ms")
	print("Build time: " + str((Time.get_ticks_msec() - build_start_time) / 1000.0) + "s")


# Draws grid points, vertices, and edges
func draw() -> void:
	var start_time = Time.get_ticks_usec()
	# Draw grid points and vertices
	var grid_point_count := len(grid_points) if show_grid_points else 0
	var vertex_count := len(vertices) if show_vertices else 0
	multimesh.set_mesh(construct_hexagon_mesh(grid_point_and_vertex_size))
	multimesh.set_instance_count(grid_point_count + vertex_count)
	# Draw grid points
	for instance in grid_point_count:
		var grid_point : Vector4 = grid_points[instance]
		var position := Vector3(grid_point.x, grid_point.y, grid_point.z)
		multimesh.set_instance_transform(instance, Transform3D().translated(position))
		var color := get_noise_color_f(grid_point.w)
		multimesh.set_instance_color(instance, color)
	# Draw vertices
	for instance in range(grid_point_count, grid_point_count + vertex_count):
		var vertex : Vector4 = vertices[instance - grid_point_count]
		var position := Vector3(vertex.x, vertex.y, vertex.z)
		var vertex_transform := Transform3D().translated(position)
		# If vertex is hidden, scale by ZERO to hide it
		if not vertex.w:
			vertex_transform = Transform3D().scaled(Vector3.ZERO)
		multimesh.set_instance_transform(instance, vertex_transform)
		multimesh.set_instance_color(instance, vertex_color)
	# Draw edges
	var edge_count := len(edges) if show_edges else 0
	edge_multimesh.set_instance_count(edge_count)
	var edge_mesh := edge_multimesh.get_mesh() as CylinderMesh
	edge_mesh.set_top_radius(edge_width / 2.0)
	edge_mesh.set_bottom_radius(edge_width / 2.0)
	var transform = Transform3D().translated(Vector3.UP * 0.5)
	for instance in edge_count:
		# Get edge
		var edge : Array = edges[instance]
		# Get starting and ending vertices of edge
		var start = vertices[get_vertex_index_3dvi(edge[0])]
		var end = vertices[get_vertex_index_3dvi(edge[1])]
		start = Vector3(start.x, start.y, start.z)
		end = Vector3(end.x, end.y, end.z)
		# Get distance and direction from start to end
		var dir : Vector3 = end - start
		var dist : float = dir.length()
		# Scale edge length by distance
		var edge_transform := transform.scaled(Vector3(1.0, dist, 1.0))
		# Rotate mesh to align with direction
		var axis := Vector3.UP.cross(dir).normalized()
		var angle := Vector3.UP.angle_to(dir)
		# Handle edge case when direction is negative of UP vector
		if axis.is_normalized():
			edge_transform = edge_transform.rotated(axis, angle)
		else:
			edge_transform = edge_transform.rotated(Vector3.LEFT, PI)
		# Translate start of edge to start point
		edge_transform = edge_transform.translated(start)
		# If edge is invalid, scale by ZERO to hide it
		if dist > cell_size * 3.5:
			edge_transform = transform.scaled(Vector3.ZERO)
		# Apply transformation
		edge_multimesh.set_instance_transform(instance, edge_transform)
		edge_multimesh.set_instance_color(instance, edge_color)
	print("Draw time: " + str((Time.get_ticks_usec() - start_time) / 1000.0)  + "ms")


func get_grid_point(x: int, y: int, z: int) -> Vector4:
	return grid_points[x * grid_resolution ** 2 + y * grid_resolution + z]


func get_vertex_index(x: int, y: int, z: int) -> int:
	return x * cell_resolution ** 2 + y * cell_resolution + z


func get_vertex_index_3dvi(v: Vector3i) -> int:
	return get_vertex_index(v.x, v.y, v.z)


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
	# Unit sphere signed distance function
	if v[v.max_axis_index()] >= bb_extent - cell_size:
		return 1.0
	if v[v.min_axis_index()] <= -bb_extent + cell_size:
		return 1.0
	var sgr = noise_scale / grid_resolution
	return v.length() * sgr - 0.8 + noise.get_noise_3dv(v)


func get_noise_color_f(f: float) -> Color:
	return Color.WHITE if f > 0.0 else Color.BLACK


func get_noise_color_3dv(v: Vector3) -> Color:
	return get_noise_color_f(get_noise_3dv(v))


func v4_to_v3(v: Vector4) -> Vector3:
	return Vector3(v.x, v.y, v.z)


func construct_hexagon_mesh(size: float) -> ArrayMesh:
	var radius := size / 2.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in HEXAGON_VERTICES:
		st.add_vertex(Vector3(vertex.x, vertex.y, 1.0) * radius)
	for index in HEXAGON_INDICES:
		st.add_index(index)
	var array_mesh := st.commit()
	var material := StandardMaterial3D.new()
	material.set_flag(BaseMaterial3D.FLAG_ALBEDO_FROM_VERTEX_COLOR, true)
	material.set_billboard_mode(BaseMaterial3D.BILLBOARD_ENABLED)
	array_mesh.surface_set_material(0, material)
	return array_mesh


func set_show_normal_buffer(visible: bool):
	var viewport := get_tree().root.get_viewport_rid()
	var mode := 5 if visible else 0
	RenderingServer.viewport_set_debug_draw(viewport, mode)
