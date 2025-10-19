# Obstacle System Documentation

## Overview

Procedural obstacle placement system for snow mountain terrain with runtime density adjustment. Supports scene-based obstacles with physics collision, 3D labels, and dynamic spawning near the player.

---

## System Architecture

### Files
- **`scripts/terrain/obstacle_factory.gd`**: Core obstacle generation and management
- **`scripts/ui/density_controls.gd`**: UI for density mode switching
- **`scripts/ui/minimap.gd`**: Minimap visualization of obstacles

### Key Components

1. **ObstacleFactory** (Node3D)
   - Scene-based obstacle creation with StaticBody3D collision
   - Physics raycast-based terrain snapping
   - Player-proximity spawning (70m radius)
   - 3D label system for obstacle identification

2. **Density Modes**
   - **Sparse**: 2 obstacles (10 × 0.2)
   - **Normal**: 10 obstacles (10 × 1.0)
   - **Dense**: 20 obstacles (10 × 2.0)

3. **Obstacle Types**
   - **Tree**: Conifer-style (CylinderMesh, 5.0m tall)
   - **Grass**: Dried grass clumps (CylinderMesh, 0.6m tall)
   - **Rock**: Three sizes (Small: 0.3m, Medium: 0.6m, Large: 1.2m)

---

## Obstacle Creation System

### Scene-Based Obstacles

Each obstacle is a **StaticBody3D** with:
- **MeshInstance3D**: Visual representation
- **CollisionShape3D**: Physics collision
- **Label3D**: Identification text (billboard)

**Collision Configuration**:
```gdscript
obstacle.collision_layer = 2  # Environment layer
obstacle.collision_mask = 0   # Doesn't detect anything
```

**Collision Shapes**:
- **Tree**: `CylinderShape3D` (radius: 0.8m, height: 5.0m)
- **Grass**: `CylinderShape3D` (radius: 0.2m, height: 0.6m)
- **Rock**: `SphereShape3D` (radius: 0.3-1.2m based on size)

### 3D Label System

**Label Configuration**:
```gdscript
label.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # Always faces camera
label.no_depth_test = true  # Visible through objects
label.modulate = Color(1, 1, 1, 1)  # White text
label.outline_modulate = Color(0, 0, 0, 1)  # Black outline
label.outline_size = 8  # Thick outline for readability
label.font_size = 32
label.pixel_size = 0.01  # 3D scale
```

**Label Heights**:
- **Tree**: 3.0m above origin
- **Grass**: 0.8m above origin
- **Rock**: Varies by size (radius × 1.5 + 0.5m)

**Label Text**:
- Tree: "Tree"
- Grass: "Grass"
- Rock: "Rock (Small/Medium/Large)"

---

## Terrain Snapping System

### Physics Raycast

**Ground Projection**:
```gdscript
func project_to_ground(world: World3D, x: float, z: float) -> Dictionary:
    var space = world.direct_space_state
    var from = Vector3(x, 1000.0, z)  # Start above
    var to = Vector3(x, -1000.0, z)   # Ray down
    var params = PhysicsRayQueryParameters3D.create(from, to)
    params.collision_mask = 2  # Terrain layer
    var hit = space.intersect_ray(params)
    return hit  # {position, normal, collider, ...} or {}
```

**Height Offsets** (compensate for mesh origin at center):
- **Tree**: +2.5m (CylinderMesh height=5.0m, origin at center)
- **Grass**: +0.3m (CylinderMesh height=0.6m, origin at center)
- **Rock**: +0.7m (SphereMesh height≈1.4m, origin at center)

### Positioning Algorithm

1. Generate random position within 70m radius of player
2. Raycast down to find terrain intersection
3. Apply mesh-type-specific height offset
4. Set obstacle global position
5. Apply random Y-axis rotation

---

## Spawning System

### Player-Proximity Spawning

**All density modes** spawn obstacles near player (70m radius):

```gdscript
func spawn_obstacles_near_player(count: int) -> void:
    var obstacle_types = generate_distribution(count)  # 30% tree, 40% grass, 30% rock

    for i in range(count):
        var angle = rng.randf() * TAU
        var dist = rng.randf() * 70.0 * 0.9 + 70.0 * 0.1
        var x = player.x + cos(angle) * dist
        var z = player.z + sin(angle) * dist

        var hit = project_to_ground(world, x, z)
        if hit.has("position"):
            create_and_place_obstacle(obstacle_types[i], hit.position)
```

**Obstacle Distribution**:
- **Tree Ratio**: 30% of total count
- **Grass Ratio**: 40% of total count
- **Rock Ratio**: 30% of total count

**Retry Logic**:
- Max attempts: `count × 10`
- Guarantees exact count placement (e.g., 10 in normal mode)

---

## Density Control System

### UI Integration

**File**: `scripts/ui/density_controls.gd`

**Buttons**:
- Sparse Button → 2 obstacles
- Normal Button → 10 obstacles
- Dense Button → 20 obstacles

**Status Label**:
- Sparse: "2 obstacles\n(sparse)"
- Normal: "10 near player\n(NORMAL)"
- Dense: "20 obstacles\n(dense)"

**Signal Flow**:
```
DensityControls → obstacle_factory.set_obstacle_density(mode)
                → obstacle_factory.density_changed signal
                → DensityControls._on_density_changed()
                → Update status label
```

---

## Minimap Visualization

### Obstacle Dots

**File**: `scripts/ui/minimap.gd`

**Dot Sizes**:
- **Trees/Rocks**: 4.0 pixel radius
- **Grass**: 2.5 pixel radius

**Drawing System**:
```gdscript
func _draw_obstacles() -> void:
    if obstacle_factory.current_density == "normal":
        # Draw scene-based obstacles
        for obstacle in obstacle_factory.normal_mode_obstacles:
            _draw_obstacle_dot(obstacle.global_position, ...)
    else:
        # Draw MultiMesh obstacles (legacy, unused)
        ...
```

**Visibility Rules**:
- Only draw obstacles within minimap view radius
- Filter by camera view size / zoom level
- Check screen bounds before drawing

**Color & Style**:
- Color: `Color(0.5, 0.5, 0.5, 0.8)` (grey with 80% alpha)
- Shape: Filled circle
- No depth test (always visible on minimap)

---

## Diagnostic System

### Debug Output

**Function**: `debug_diagnose()`

**Checks**:
1. Terrain StaticBody3D existence
2. Collision layer/mask configuration
3. Terrain group membership ("terrain_static")
4. Player reference and position
5. MultiMesh instance counts
6. Tree mesh AABB (bounding box)

**Console Output**:
```
[ObstacleFactory] === DIAGNOSTIC START ===
[Diag] ✓ Terrain StaticBody3D found: Terrain
[Diag]   - Collision layer: 2
[Diag]   - Collision mask: 0
[Diag]   - Has group 'terrain_static': true
[Diag] ✓ Player found: Player
[Diag]   - Position: (0.0, 355.0, -30.0)
[Diag] MultiMesh instances:
[Diag]   - Trees: 0
[Diag]   - Grass: 0
[Diag]   - Rocks: 0
[Diag] Tree mesh AABB: [(-1.5, -2.5, -1.5) - (1.5, 2.5, 1.5)]
[Diag]   - Visual bottom Y: -2.5
[Diag]   - Height: 5.0
[ObstacleFactory] === DIAGNOSTIC END ===
```

---

## Performance Considerations

### Scene-Based vs MultiMesh

**Current Approach**: Scene-based obstacles (10-20 instances)
- ✅ Full physics collision per obstacle
- ✅ Individual node control (labels, materials)
- ✅ Easy debugging and inspection
- ✅ Suitable for low obstacle counts (< 50)

**Legacy Approach**: MultiMesh (100-600 instances)
- ⚠️ No per-instance collision (would need custom system)
- ⚠️ No per-instance labels
- ✅ High performance for thousands of instances
- ❌ Removed in favor of scene-based for better collision

### Optimization

**Memory Management**:
- Clear old obstacles before spawning new ones
- `queue_free()` removes nodes from scene tree
- `normal_mode_obstacles.clear()` releases array references

**Raycast Efficiency**:
- Single raycast per obstacle (not per frame)
- Collision mask limits ray to terrain layer only
- Early exit on raycast failure

---

## API Reference

### ObstacleFactory

```gdscript
class_name ObstacleFactory extends Node3D

# Exports
@export var terrain_size := Vector2(800, 800)
@export var seed_value := 12345
@export var terrain_collision_mask: int = 2
@export var player_radius_m: float = 70.0

# Public Methods
func set_obstacle_density(mode: String) -> void
func get_current_density() -> String
func clear_obstacles() -> void
func debug_diagnose() -> void
func project_to_ground(world: World3D, x: float, z: float) -> Dictionary

# Signals
signal density_changed(mode: String)
```

### DensityControls

```gdscript
class_name DensityControls extends VBoxContainer

# Exports
@export var obstacle_factory: ObstacleFactory

# Public Methods
func get_current_mode() -> String
func set_buttons_enabled(enabled: bool) -> void

# Signals
signal density_mode_changed(mode: String)
```

---

## Integration with Terrain

### Collision Layer Setup

**Required Configuration**:

1. **Terrain** (`terrain_generator.gd`):
```gdscript
static_body.collision_layer = 2  # Environment layer
static_body.collision_mask = 0
static_body.add_to_group("terrain_static")  # For obstacle raycast
```

2. **Player** (`player.tscn`):
```gdscript
collision_mask = 2  # Detects environment (terrain + obstacles)
```

3. **Obstacles** (`obstacle_factory.gd`):
```gdscript
obstacle.collision_layer = 2  # Same as terrain
obstacle.collision_mask = 0  # Static, doesn't detect anything
```

### Physics Layer Table

| Object | Layer | Mask | Detects |
|--------|-------|------|---------|
| **Player** | 1 (Player) | 2 (Environment) | Terrain, obstacles |
| **Terrain** | 2 (Environment) | 0 (None) | Nothing |
| **Obstacles** | 2 (Environment) | 0 (None) | Nothing |

---

## Scene Hierarchy

```
Main (Node3D)
└─ ProceduralSlope (Node3D)
    ├─ Terrain (StaticBody3D) [layer=2, group="terrain_static"]
    │   ├─ TerrainMesh (MeshInstance3D)
    │   └─ CollisionShape3D
    └─ ObstacleFactory (Node3D)
        ├─ Trees (MultiMeshInstance3D) [HIDDEN in scene-based mode]
        ├─ Grass (MultiMeshInstance3D) [HIDDEN in scene-based mode]
        ├─ Rocks (MultiMeshInstance3D) [HIDDEN in scene-based mode]
        ├─ Tree (StaticBody3D)
        │   ├─ MeshInstance3D
        │   ├─ CollisionShape3D
        │   └─ Label3D ("Tree")
        ├─ Grass (StaticBody3D)
        │   ├─ MeshInstance3D
        │   ├─ CollisionShape3D
        │   └─ Label3D ("Grass")
        └─ Rock (StaticBody3D)
            ├─ MeshInstance3D
            ├─ CollisionShape3D
            └─ Label3D ("Rock (Medium)")
```

---

## Troubleshooting

### Obstacles Floating in Air

**Symptom**: Obstacles appear above terrain surface

**Cause**: Height offset not accounting for mesh origin at center

**Solution**: Use `_get_obstacle_height_offset()` with proper offsets:
- Tree: +2.5m (half of 5m height)
- Grass: +0.3m (half of 0.6m height)
- Rock: +0.7m (half of ~1.4m height)

### Player Passes Through Obstacles

**Symptom**: No collision with obstacles

**Cause**: Collision layer/mask mismatch

**Solution**: Verify configuration:
- Player `collision_mask` includes bit 2 (Environment)
- Obstacle `collision_layer` is set to 2
- CollisionShape3D properly sized and positioned

### Obstacles Not Appearing on Minimap

**Symptom**: Minimap shows no obstacle dots

**Cause**: Minimap not checking scene-based obstacles

**Solution**: Verify `minimap.gd` checks `normal_mode_obstacles` array when `current_density == "normal"`

### Raycast Failures

**Symptom**: Console shows "Raycast miss" warnings

**Cause**: Terrain collision not initialized or wrong collision mask

**Solution**:
1. Ensure terrain has group "terrain_static"
2. Wait 2 physics frames before spawning
3. Verify `terrain_collision_mask = 2` matches terrain layer

---

## Future Enhancements

### Planned Features

1. **Collision Response Tuning**:
   - Player bounce-back effect on collision
   - Speed reduction based on obstacle type
   - Different collision behaviors (tree vs grass)

2. **Visual Polish**:
   - Obstacle LOD system for distant objects
   - Material variations (different bark/leaf colors)
   - Shadows and ambient occlusion

3. **Gameplay Integration**:
   - Obstacle destruction (breaking through grass)
   - Score penalties for collisions
   - Achievement system (dodge X obstacles)

4. **Performance Optimization**:
   - Spatial partitioning for large obstacle counts
   - Frustum culling for off-screen obstacles
   - Dynamic batching for similar obstacle types

---

## References

- **SLOPE.md**: Terrain generation and material setup
- **PLAYER.md**: Player collision configuration
- **UI.md**: UI system architecture and density controls
- **claude_fix_obstacle_prompt.md**: Original requirements (archived)
- **claude_snow_mountain_prompt.md**: Snow mountain specifications (archived)
