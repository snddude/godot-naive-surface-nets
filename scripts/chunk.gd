class_name Chunk
extends StaticBody3D

const VOXEL_VERTICES: PackedVector3Array = [
	Vector3(0.0, 0.0, 0.0),
	Vector3(1.0, 0.0, 0.0),
	Vector3(1.0, 0.0, 1.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(1.0, 1.0, 0.0),
	Vector3(0.0, 1.0, 1.0),
	Vector3(1.0, 1.0, 1.0),
]
const VOXEL_EDGE_INDICES: Array = [
	[0, 1],
	[1, 2],
	[2, 3],
	[3, 0],
	[4, 5],
	[5, 6],
	[6, 7],
	[7, 4],
	[0, 4],
	[1, 5],
	[2, 6],
	[3, 7],
]
const VOXEL_NEIGHBOURS: PackedVector3Array = [
	Vector3(1.0, 0.0, 0.0),
	Vector3(1.0, 1.0, 0.0),
	Vector3(0.0, 1.0, 0.0),
	Vector3(0.0, 1.0, 1.0),
	Vector3(0.0, 0.0, 1.0),
	Vector3(1.0, 0.0, 1.0),
]
const QUAD_NEIGHBOURS: PackedVector3Array = [
	Vector3(0, 1, 2),
	Vector3(0, 5, 4),
	Vector3(2, 3, 4),
]
const QUAD_NEIGHBOUR_VERTEX_ORDERS: Array = [
	[0, 1, 2],
	[2, 1, 0],
]

@export var size: Vector3i
@export_group("Noise")
@export var iso_value: float
@export var noise: FastNoiseLite
@export_group("Nodes")
@export var mesh_instance: MeshInstance3D
@export var collision_shape: CollisionShape3D

var _active_voxels: Dictionary[int, int] = {}
var _vertices := PackedVector3Array([])
var _indices := PackedInt32Array([])
var _normals: PackedVector3Array = []


func _ready() -> void:
	_time(_discover_vertices, "Vertex discovery")
	_time(_triangulate, "Triangulation")


func _discover_vertices() -> void:
	# Initialize mesh stuff.
	var active_voxel_index: int = 0
	var vertex_index: int = 0
	var val1: float = 0.0
	var val2: float = 0.0
	var t: float = 0.0
	var voxel_is_active: bool = false

	var voxel_values: Array[float]
	voxel_values.resize(8)

	var bipolar_voxel_edges: Array[bool]
	bipolar_voxel_edges.resize(12)

	var voxel_position := Vector3.ZERO
	var voxel_global_position := Vector3.ZERO
	var voxel_vertex_position := Vector3.ZERO
	var edge_intersection_points_sum := Vector3.ZERO
	var p1 := Vector3.ZERO
	var p2 := Vector3.ZERO
	var value := Vector3.ZERO
	var edge_intersection_points := PackedVector3Array([])

	# Calculate mesh stuff.
	for x: int in size.x:
		for y: int in size.y:
			for z: int in size.z:
				voxel_is_active = false
				edge_intersection_points_sum = Vector3.ZERO
				edge_intersection_points = PackedVector3Array([])

				voxel_position = Vector3(x, y, z)
				voxel_global_position = voxel_position + global_position

				for i: int in 8:
					voxel_values[i] = _sample_noisev(VOXEL_VERTICES[i] + voxel_global_position)

				for i: int in 12:
					if not _is_edge_bipolar(
							voxel_values[VOXEL_EDGE_INDICES[i][0]],
							voxel_values[VOXEL_EDGE_INDICES[i][1]]):
						continue

					voxel_is_active = true

					p1 = VOXEL_VERTICES[VOXEL_EDGE_INDICES[i][0]]
					p2 = VOXEL_VERTICES[VOXEL_EDGE_INDICES[i][1]]
					val1 = voxel_values[VOXEL_EDGE_INDICES[i][0]]
					val2 = voxel_values[VOXEL_EDGE_INDICES[i][1]]
					t = (iso_value - val1) / (val2 - val1)

					value = p1 + t * (p2 - p1)

					edge_intersection_points.push_back(value)
					edge_intersection_points_sum += value

				if not voxel_is_active:
					continue

				voxel_vertex_position = (
						edge_intersection_points_sum / edge_intersection_points.size())

				active_voxel_index = _get_active_voxel_index(x, y, z)
				vertex_index = _vertices.size()
				_active_voxels[active_voxel_index] = vertex_index

				_vertices.push_back(voxel_vertex_position + voxel_global_position)
				_normals.push_back(Vector3(
					voxel_values[3] - voxel_values[0],
					voxel_values[4] - voxel_values[0],
					voxel_values[1] - voxel_values[0],
				).normalized())


func _triangulate() -> void:
	# Initialize triangulation stuff.
	var vertex_index: int = 0
	var neighbour1: int = 0
	var neighbour2: int = 0
	var neighbour3: int = 0
	var v0: int = 0
	var v1: int = 0
	var v2: int = 0
	var v3: int = 0
	var voxel_coordinates := Vector3.ZERO
	var voxel_global_coordinates := Vector3.ZERO

	var edge_scalars: Array
	edge_scalars.resize(3)

	var neighbour_vertices: Array[int] = []
	var vertex_order: Array = []

	for voxel_index: int in _active_voxels:
		vertex_index = _active_voxels[voxel_index]
		voxel_coordinates = _get_active_voxel_coordinates(voxel_index)

		if voxel_coordinates.x == 0 or voxel_coordinates.y == 0 or voxel_coordinates.z == 0:
			continue

		voxel_global_coordinates = voxel_coordinates + global_position

		edge_scalars[0] = [
			_sample_noisev(voxel_global_coordinates + VOXEL_VERTICES[0]),
			_sample_noisev(voxel_global_coordinates + VOXEL_VERTICES[3]),
		]
		edge_scalars[1] = [
			_sample_noisev(voxel_global_coordinates + VOXEL_VERTICES[4]),
			_sample_noisev(voxel_global_coordinates + VOXEL_VERTICES[0]),
		]
		edge_scalars[2] = [
			_sample_noisev(voxel_global_coordinates + VOXEL_VERTICES[0]),
			_sample_noisev(voxel_global_coordinates + VOXEL_VERTICES[1]),
		]

		for i: int in 3:
			neighbour1 = _get_active_voxel_index(
					voxel_coordinates.x - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].x].x,
					voxel_coordinates.y - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].x].y,
					voxel_coordinates.z - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].x].z)
			neighbour2 = _get_active_voxel_index(
					voxel_coordinates.x - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].y].x,
					voxel_coordinates.y - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].y].y,
					voxel_coordinates.z - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].y].z)
			neighbour3 = _get_active_voxel_index(
					voxel_coordinates.x - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].z].x,
					voxel_coordinates.y - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].z].y,
					voxel_coordinates.z - VOXEL_NEIGHBOURS[QUAD_NEIGHBOURS[i].z].z)

			if (neighbour1 not in _active_voxels
					or neighbour2 not in _active_voxels
					or neighbour3 not in _active_voxels):
				continue

			neighbour_vertices = [
				_active_voxels[neighbour1],
				_active_voxels[neighbour2],
				_active_voxels[neighbour3]
			]

			vertex_order = (QUAD_NEIGHBOUR_VERTEX_ORDERS[0] 
					if edge_scalars[i][1] < edge_scalars[i][0] 
					else QUAD_NEIGHBOUR_VERTEX_ORDERS[1])

			v0 = vertex_index
			v1 = neighbour_vertices[vertex_order[0]]
			v2 = neighbour_vertices[vertex_order[1]]
			v3 = neighbour_vertices[vertex_order[2]]

			_indices.append(v0)
			_indices.append(v1)
			_indices.append(v2)

			_indices.append(v0)
			_indices.append(v2)
			_indices.append(v3)

	# Generate the mesh.
	var arrays: Array
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_INDEX] = _indices
	arrays[Mesh.ARRAY_NORMAL] = _normals

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	mesh_instance.set_mesh(arr_mesh)
	collision_shape.set_shape(mesh_instance.mesh.create_trimesh_shape())

	# Cleanup.
	_active_voxels.clear()
	_vertices.clear()
	_indices.clear()


func _sample_noise(x: float, y: float, z: float) -> float:
	return noise.get_noise_3d(x, y, z)


func _sample_noisev(at: Vector3) -> float:
	return _sample_noise(at.x, at.y, at.z)


func _is_scalar_positive(scalar: float) -> bool:
	return scalar >= iso_value


func _is_edge_bipolar(scalar1: float, scalar2: float) -> bool:
	return _is_scalar_positive(scalar1) != _is_scalar_positive(scalar2)


func _get_active_voxel_index(x: float, y: float, z: float) -> int:
	return int(x + (y * size.x) + (z * size.x * size.y))


func _get_active_voxel_coordinates(voxel_index: int) -> Vector3:
	@warning_ignore("integer_division")
	return Vector3(
			voxel_index % size.x,
			(voxel_index / size.x) % size.y,
			voxel_index / (size.x * size.y))


func _time(function: Callable, operation: String) -> void:
	var start_time: int = Time.get_ticks_msec()
	function.call()
	print("%s time: %d msec"%[operation, Time.get_ticks_msec() - start_time])
