# Obstacle Generation File Locations & References

## Absolute File Paths

### Main Obstacle-Related Files

1. **V1 Obstacle Generation**
   - **File**: `/Users/kimhanui/projects/godot/ski-boarder/scripts/terrain/terrain_generator.gd`
   - **Functions**:
     - `_generate_procedural_obstacles()` - Lines 563-606
     - `_build_obstacles()` - Lines 419-476
   - **Called from**: `apply_slope_data()` - Lines 41 & 61

2. **V2 Terrain Generator** 
   - **File**: `/Users/kimhanui/projects/godot/ski-boarder/scripts/terrain/terrain_generator_v2.gd`
   - **Function**: `create_flat_terrain()` - Lines 14-65
   - **Note**: Does NOT generate obstacles
   - **Obstacle mesh building**: `_build_flat_mesh()` - Lines 70-160+ (only creates terrain)

3. **ObstacleFactory** (Used for V2 obstacle spawning)
   - **File**: `/Users/kimhanui/projects/godot/ski-boarder/scripts/terrain/obstacle_factory.gd`
   - **Key Functions**:
     - `_ready()` - Lines 52-68 (initialization)
     - `set_obstacle_density()` - Lines 205-220 (PROBLEM: calls spawn_obstacles_near_player)
     - `spawn_obstacles_near_player()` - Lines 422-500 (MAIN SPAWNING FUNCTION)
     - `_find_player()` - Lines 335-339 (player lookup)
     - `_create_obstacle_scene()` - Lines 503-595 (creates individual obstacles)
     - `project_to_ground()` - Lines 406-418 (raycast to find ground)

4. **ProceduralSlope** (Terrain coordinator)
   - **File**: `/Users/kimhanui/projects/godot/ski-boarder/scenes/environment/procedural_slope.gd`
   - **Key Functions**:
     - `_ready()` - Lines 29-99 (initialization with obstacle setup)
     - `_load_and_build_terrain()` - Lines 39-99 (loads both V1 and V2)
     - `_create_test_obstacles_fixed()` - Lines 272-313 (test mode - WORKS PROPERLY)
   - **Obstacle initialization**: Lines 33-36

5. **ProceduralSlope Scene**
   - **File**: `/Users/kimhanui/projects/godot/ski-boarder/scenes/environment/procedural_slope.tscn`
   - **Structure**: 
     ```
     ProceduralSlope (Node3D) [procedural_slope.gd]
     └─ ObstacleFactory (Node3D) [obstacle_factory.gd]
     ```

---

## Detailed Line References

### V1 Obstacle Flow (WORKING)

**terrain_generator.gd:41** - Call obstacle generation:
```gdscript
obstacles_data = _generate_procedural_obstacles(config, rng, path_data, terrain_data)
```

**terrain_generator.gd:61** - Build obstacles from data:
```gdscript
var obstacles_node = _build_obstacles(data.get("obstacles", []))
```

**terrain_generator.gd:563-606** - Generate obstacle data:
```gdscript
static func _generate_procedural_obstacles(config: Dictionary, rng: RandomNumberGenerator, 
                                          path_data: Dictionary, terrain_data: Dictionary) -> Array:
    # Returns: [{type: "tree"|"rock", pos: [x, y, z], scale: float}, ...]
    # ✓ Creates obstacle data based on difficulty config
    # ✓ Places obstacles off the main path
    # ✓ Calculates heights based on terrain config
```

**terrain_generator.gd:419-476** - Convert data to scene:
```gdscript
static func _build_obstacles(obstacles_data: Array) -> Node3D:
    var obstacles_node = Node3D.new()
    # For each obstacle dict: create MeshInstance3D and position it
    # ✓ Guaranteed to execute (part of terrain generation)
```

---

### V2 Obstacle Flow (NOT WORKING)

**procedural_slope.gd:33-36** - Try to initialize obstacles:
```gdscript
var obstacle_factory = get_node_or_null("ObstacleFactory")
if obstacle_factory:
    obstacle_factory.call_deferred("set_obstacle_density", "normal")
```

**terrain_generator_v2.gd:14-65** - Create V2 terrain:
```gdscript
static func create_flat_terrain(...) -> StaticBody3D:
    # ✗ Does NOT generate obstacles
    # Only creates terrain mesh and collision
    # Returns: StaticBody3D with TerrainMesh + CollisionShape3D
```

**obstacle_factory.gd:205-220** - Set density (calls spawner):
```gdscript
func set_obstacle_density(mode: String) -> void:
    # ...
    spawn_obstacles_near_player(total_count)  # LINE 217
    # ✗ PROBLEM: Player may not exist yet
```

**obstacle_factory.gd:422-443** - Spawn obstacles (FAILS HERE):
```gdscript
func spawn_obstacles_near_player(count: int) -> void:
    # ...
    if not player:
        push_warning("[ObstacleFactory] No player found, cannot spawn near player")
        return  # ← EXITS HERE - NO OBSTACLES!
    # ...
```

**obstacle_factory.gd:57-59** - Player lookup (runs in _ready):
```gdscript
await get_tree().process_frame
player = _find_player()
```

**obstacle_factory.gd:335-339** - Find player:
```gdscript
func _find_player() -> Node3D:
    var players = get_tree().get_nodes_in_group("player")
    if players.size() > 0:
        return players[0]
    return null  # ← Returns null if player not in "player" group
```

**obstacle_factory.gd:478** - Raycast for ground:
```gdscript
var hit = project_to_ground(get_world_3d(), x, z)
# If raycast misses or player is None, obstacles don't spawn
```

---

## Problem Analysis by File

### `/scripts/terrain/terrain_generator_v2.gd`
**Issue**: No obstacle generation function
**Lines**: 14-65 (entire `create_flat_terrain()`)
**Effect**: V2 terrain returns terrain-only StaticBody3D

```
Expected: Similar to terrain_generator._generate_procedural_obstacles()
Actual:   Returns only terrain mesh + collision
Result:   0 obstacles on V2
```

### `/scenes/environment/procedural_slope.gd`
**Issue**: Timing - ObstacleFactory initialized before player ready
**Lines**: 29-99 (_ready function)
**Problematic**: Lines 33-36

```
Timeline:
1. _load_and_build_terrain() ← Creates terrain
2. call_deferred("set_obstacle_density", "normal") ← Tries to spawn obstacles
3. BUT: Player hasn't been positioned yet (happens elsewhere in Main scene)
4. Result: ObstacleFactory._find_player() returns null
```

**Potential fix**: Wait for both terrain AND player before calling set_obstacle_density()

### `/scripts/terrain/obstacle_factory.gd`
**Issue**: Depends on player reference that may not exist
**Critical Lines**:
- 52-68: `_ready()` - Sets up player reference
- 205-220: `set_obstacle_density()` - Calls spawn function
- 422-500: `spawn_obstacles_near_player()` - Main spawner with player check
- 335-339: `_find_player()` - Looks for player in "player" group

**Problem Flow**:
1. ObstacleFactory._ready() calls `_find_player()` (line 59)
2. Player may not be in scene yet
3. `player = null`
4. Later, `set_obstacle_density()` is called
5. `spawn_obstacles_near_player()` checks `if not player: return`
6. Result: No obstacles

**Raycast Issue** (secondary):
- Line 478: Uses raycasts to find ground height
- Requires terrain collision to be fully initialized
- V2 may have collision issues on first frame

---

## Working Reference: Test Mode Approach

**File**: `/scenes/environment/procedural_slope.gd`
**Function**: `_create_test_obstacles_fixed()` - Lines 272-313
**Status**: ✓ WORKS CORRECTLY

```gdscript
func _create_test_obstacles_fixed(ground_y: float, hover_height: float) -> void:
    var obstacle_factory = get_node_or_null("ObstacleFactory")
    
    # Get all obstacles ready FIRST
    var positions = [
        {"type": "tree", "pos": Vector3(5.0, 0, -40.0), "offset": TREE_OFFSET},
        {"type": "rock", "pos": Vector3(-5.0, 0, -40.0), "offset": ROCK_OFFSET},
        # ... more obstacles ...
    ]
    
    for data in positions:
        # Create obstacle using factory method (line 295)
        var obstacle = obstacle_factory._create_obstacle_scene(data["type"], rng)
        
        # Position correctly accounting for terrain height
        obstacle.global_position = Vector3(
            data["pos"].x,
            ground_y + hover_height + data["offset"],  # ← Proper height calc
            data["pos"].z
        )
        
        # Add to terrain (line 307-310)
        var active_terrain = _get_active_terrain()
        if active_terrain:
            active_terrain.add_child(obstacle)  # ← Direct parent assignment
        
        # Track for cleanup
        _test_obstacles.append(obstacle)
```

**Why it works**:
1. No dependency on player position
2. Uses fixed positions relative to spawn
3. Properly calculates obstacle heights
4. Directly adds to terrain node
5. Successfully creates obstacles on V2

---

## Configuration Files

### Difficulty Config
**File**: `/scripts/terrain/difficulty_config.gd`
- Provides: `obstacle_count_range`, `obstacle_min_distance`, `obstacle_max_distance`, `obstacle_scale_range`
- Used by: `_generate_procedural_obstacles()` (V1 only)

### Project Settings
**File**: `project.godot`
- Collision layers configuration
- Physics settings
- Input mappings

---

## Scene Structure Files

### Main Scene
**File**: `/scenes/main.tscn`
- Contains: Player, ProceduralSlope, UI
- References: Player node must be in "player" group

### ProceduralSlope Scene
**File**: `/scenes/environment/procedural_slope.tscn`
```
ProceduralSlope (Node3D)
├─ script: procedural_slope.gd
└─ ObstacleFactory (Node3D)
   └─ script: obstacle_factory.gd
```

---

## Summary of Code Locations

| Aspect | File | Lines | Status |
|--------|------|-------|--------|
| V1 Obstacle Generation | terrain_generator.gd | 563-606 | ✓ Working |
| V1 Obstacle Building | terrain_generator.gd | 419-476 | ✓ Working |
| V2 Obstacle Generation | terrain_generator_v2.gd | N/A | ✗ Missing |
| ObstacleFactory Setup | obstacle_factory.gd | 52-68 | ⚠ Timing issue |
| Obstacle Spawning | obstacle_factory.gd | 422-500 | ⚠ Player dependency |
| Player Reference | obstacle_factory.gd | 335-339 | ⚠ May be null |
| Raycast to Ground | obstacle_factory.gd | 406-418 | ⚠ May fail |
| ProceduralSlope Init | procedural_slope.gd | 29-99 | ⚠ Timing issue |
| Test Mode (WORKS) | procedural_slope.gd | 272-313 | ✓ Reference |

