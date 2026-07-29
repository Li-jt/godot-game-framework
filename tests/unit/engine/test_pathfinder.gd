# tests/unit/engine/test_pathfinder.gd
extends GutTest

var _heuristic: ManhattanHeuristic
var _pathfinder: Pathfinder


func before_each() -> void:
	_heuristic = ManhattanHeuristic.new()
	_pathfinder = Pathfinder.new(_heuristic)


func after_each() -> void:
	_pathfinder = null; _heuristic = null


func test_manhattan_heuristic_correct() -> void:
	var h := ManhattanHeuristic.new()
	assert_eq(h.estimate(Vector2i(0, 0), Vector2i(3, 4)), 7)


func test_single_node_start_equals_goal() -> void:
	var graph = _make_graph(5, [])
	var traversal = _make_traversal([])
	var path = _pathfinder.find_path(Vector2i(0, 0), Vector2i(0, 0), graph, traversal)
	assert_eq(path.size(), 1)


func test_a_star_finds_path() -> void:
	var graph = _make_graph(5, [])
	var traversal = _make_traversal([])
	var path = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 2), graph, traversal)
	assert_true(path.size() > 0)


func test_blocked_goal_returns_empty() -> void:
	var blocked: Array[Vector2i] = [Vector2i(2, 2)]
	var graph = _make_graph(5, [])
	var traversal = _make_traversal(blocked)
	var path = _pathfinder.find_path(Vector2i(0, 0), Vector2i(2, 2), graph, traversal)
	assert_eq(path.size(), 0)


# ============================================================
# 辅助
# ============================================================

func _make_graph(p_size: int, _blocked: Array):
	var s := GDScript.new()
	s.source_code = """
extends IPathGraph
var _size: int
func _init(p_size: int): _size = p_size
func get_neighbors(p_node) -> Array:
	var neighbors: Array = []
	var cell: Vector2i = p_node
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var next := cell + d
		if next.x >= 0 and next.x < _size and next.y >= 0 and next.y < _size:
			neighbors.append(next)
	return neighbors
func cost(_a, _b) -> float: return 1.0
"""
	s.reload()
	return s.new(p_size)


func _make_traversal(p_blocked: Array[Vector2i]):
	var s := GDScript.new()
	s.source_code = """
extends ITraversal
var _blocked: Array = []
func _init(p_blocked: Array): _blocked = p_blocked
func is_walkable(p_pos) -> bool:
	for b in _blocked:
		if b == p_pos: return false
	return true
"""
	s.reload()
	return s.new(p_blocked)
