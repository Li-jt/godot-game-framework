# GF_Pathfinder

> 适用版本: 0.3.0 | 继承: GF_Pathfinder -> RefCounted

## 概述

A* 寻路引擎。可实例化，同一实例可服务多种单位类型——每次 `find_path()` 传入不同的 `GF_IPathGraph`（地图结构）和 `GF_ITraversal`（通行规则），寻路逻辑完全由调用方提供的数据驱动。适用于网格地图寻路、图结构寻路等场景。**不适用于**实时数百单位同时寻路的性能敏感场景（需在 Game 层自行实现分流或分层寻路）。

## 属性

GF_Pathfinder 无公开属性。启发式函数通过构造函数注入，内部持有。

## 公共方法

### \_init(p_heuristic: GF_IHeuristic = null) -> void

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_heuristic | GF_IHeuristic | 启发式距离估算函数。传 `null` 时默认使用 `GF_ManhattanHeuristic.new()` |

**示例:**

```gdscript
# 使用默认曼哈顿启发式
var pf := GF_Pathfinder.new()

# 注入自定义启发式
var pf2 := GF_Pathfinder.new(MyCustomHeuristic.new())
```

---

### find_path(p_from: Vector2i, p_to: Vector2i, p_graph: GF_IPathGraph, p_traversal: GF_ITraversal) -> Array[Vector2i]

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_from | Vector2i | 起点坐标 |
| p_to | Vector2i | 终点坐标 |
| p_graph | GF_IPathGraph | 地图结构，提供邻居列表和移动代价 |
| p_traversal | GF_ITraversal | 通行规则，判断节点是否可行走 |

**返回值:** `Array[Vector2i]` — 从起点到终点的路径节点序列（含起点和终点）。若终点不可行走或无路径可达，返回空数组 `[]`。若起点等于终点，返回 `[p_from]`。

**示例:**

```gdscript
var pf := GF_Pathfinder.new()
var graph := MyGridGraph.new()       # 实现 GF_IPathGraph
var traversal := MyGroundTraversal.new()  # 实现 GF_ITraversal

var path := pf.find_path(Vector2i(0, 0), Vector2i(10, 5), graph, traversal)
if path.is_empty():
    log.warning("Pathfinder", "无法到达目标")
else:
    for pos in path:
        print(pos)
```

---

# GF_IPathGraph

> 适用版本: 0.3.0 | 继承: GF_IPathGraph -> RefCounted

## 概述

寻路地图结构接口。定义节点邻居查询和节点间移动代价。Game 层通过实现此接口将自定义地图数据接入 `GF_Pathfinder`。**不直接实例化**——始终在 Game 层创建子类。

## 公共方法

### get_neighbors(p_pos: Vector2i) -> Array

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_pos | Vector2i | 当前节点坐标 |

**返回值:** `Array[Vector2i]` — 可达的邻居坐标列表。**必须由子类重写**，基类调用 `push_error()`。

**示例:**

```gdscript
# 四方向网格实现
func get_neighbors(p_pos: Vector2i) -> Array:
    var dirs := [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
    var result: Array[Vector2i] = []
    for d in dirs:
        var nb := p_pos + d
        if _in_bounds(nb):
            result.append(nb)
    return result
```

---

### get_cost(p_from: Vector2i, p_to: Vector2i) -> float

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_from | Vector2i | 起点坐标 |
| p_to | Vector2i | 终点坐标 |

**返回值:** `float` — 两点间的移动代价。默认返回 `1.0`。子类可重写以实现不同地形代价（如沼泽=3.0，道路=0.5）。

---

# GF_ITraversal

> 适用版本: 0.3.0 | 继承: GF_ITraversal -> RefCounted

## 概述

寻路通行规则接口。判断指定坐标是否可行走。每次 `find_path()` 调用可传入不同实现，支持同一地图上按单位类型（地面、飞行、水路）切换通行逻辑。**不直接实例化**——始终在 Game 层创建子类。

## 公共方法

### is_walkable(p_pos: Vector2i) -> bool

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_pos | Vector2i | 待检查的坐标 |

**返回值:** `bool` — 该坐标是否可行走。**必须由子类重写**，基类调用 `push_error()` 并返回 `false`。

**示例:**

```gdscript
# 地面单位：不可以通过水域
func is_walkable(p_pos: Vector2i) -> bool:
    if _tilemap.get_cell_tile_data(0, p_pos).get_custom_data("is_water"):
        return false
    return not _blocker_map.has(_key(p_pos))
```

---

# GF_IHeuristic

> 适用版本: 0.3.0 | 继承: GF_IHeuristic -> RefCounted

## 概述

A* 启发式距离估算接口。估算两个节点之间的最短路径距离。不同实现对应不同移动规则（四方向、八方向、六边形网格等）。可注入 `GF_Pathfinder.new()` 的构造函数。**不直接实例化**——使用 `GF_ManhattanHeuristic` 或创建自定义子类。

## 公共方法

### estimate(p_from: Vector2i, p_to: Vector2i) -> int

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_from | Vector2i | 起点坐标 |
| p_to | Vector2i | 终点坐标 |

**返回值:** `int` — 估算距离（整数）。**必须由子类重写**。估算值必须**不高估**（admissible），否则 A* 不再保证最短路径。

**示例:**

```gdscript
# 八方向切比雪夫距离
func estimate(p_from: Vector2i, p_to: Vector2i) -> int:
    return maxi(absi(p_from.x - p_to.x), absi(p_from.y - p_to.y))
```

---

# GF_ManhattanHeuristic

> 适用版本: 0.3.0 | 继承: GF_ManhattanHeuristic -> GF_IHeuristic -> RefCounted

## 概述

曼哈顿距离启发式。适用于四方向网格移动（上下左右），计算 `|x1 - x2| + |y1 - y2|`。是 `GF_Pathfinder` 的默认启发式函数。

## 公共方法

### estimate(p_from: Vector2i, p_to: Vector2i) -> int

**参数:**

| 参数 | 类型 | 描述 |
|------|------|------|
| p_from | Vector2i | 起点坐标 |
| p_to | Vector2i | 终点坐标 |

**返回值:** `int` — `abs(p_from.x - p_to.x) + abs(p_from.y - p_to.y)`

**示例:**

```gdscript
var h := GF_ManhattanHeuristic.new()
var dist := h.estimate(Vector2i(0, 0), Vector2i(3, 4))  # 7
```

## See Also

- `GF_IPathGraph` — 地图结构接口
- `GF_ITraversal` — 通行规则接口
- `GF_IHeuristic` — 启发式函数接口
