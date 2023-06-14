extends Node

var bounding_box_size := 2.0
var cell_resolution := 20
var cell_size := bounding_box_size / cell_resolution

var grid_point_size := cell_size / 5.0


@onready var node3d := $Node3D
@onready var multimesh : MultiMesh = $Node3D/MultiMeshInstance3D.get_multimesh()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Create grid points
	var bb_extent := bounding_box_size / 2.0
	multimesh.set_instance_count(cell_resolution ** 3)
	var instance_idx := 0
	for x in Vector3(-bb_extent, bb_extent, cell_size):
		for y in Vector3(-bb_extent, bb_extent, cell_size):
			for z in Vector3(-bb_extent, bb_extent, cell_size):
				var scale := Vector3.ONE * grid_point_size
				var position := Vector3(x, y, z)
				var transform := Transform3D().scaled(scale).translated(position)
				multimesh.set_instance_transform(instance_idx, transform)
				var color := get_noise_color_3dv(position)
				multimesh.set_instance_color(instance_idx, color)
				instance_idx += 1

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	pass


func get_noise_3dv(v: Vector3) -> float:
	# Unit sphere
	if v.length() <= 1.0:
		return -1.0
	else:
		return 1.0


func get_noise_color_3dv(v: Vector3) -> Color:
	var value := get_noise_3dv(v)
	if value >= 0.0:
		return Color.WHITE
	else:
		return Color.BLACK
