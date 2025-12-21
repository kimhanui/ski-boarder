# UI System Documentation

Complete guide to all user interface systems in the Ski Boarder game.

---

## 1) UI Overview

The game features multiple UI systems for player feedback and game configuration:

1. **Title Screen**
   - Game start menu
   - Blurred semi-transparent background
   - Options and quit buttons

2. **HUD (Heads-Up Display)**
   - Speed indicator
   - Camera mode label
   - Position/time display

3. **Difficulty Selector**
   - Easy/Medium/Hard terrain generation

4. **Density Controls**
   - Sparse/Normal/Dense obstacle placement

5. **Minimap**
   - Top-down view with player position
   - Obstacle indicators
   - Terrain visualization

---

## 2) Title Screen

**File**: `scenes/ui/title_screen.tscn`
**Script**: `scripts/ui/title_screen.gd`

**Purpose**: Game's main menu screen with semi-transparent blurred background.

### UI Layout

```
TitleScreen (Control)
├─ BackgroundGradient (ColorRect) - Dark blue semi-transparent
├─ BlurOverlay (ColorRect) - Additional blur effect layer
└─ CenterContainer
   └─ VBoxContainer
      ├─ TitleLabel "🏂 Ski Boarder" (72pt)
      ├─ SubtitleLabel "3D Backcountry Snowboard Game" (24pt)
      ├─ Spacer (40px)
      ├─ StartButton "게임 시작" (300x70, 32pt)
      ├─ OptionsButton "설정" (300x60, 24pt)
      └─ QuitButton "종료" (300x60, 24pt)
```

### Features

**Visual Design**:
- Dual-layer semi-transparent background
  - BackgroundGradient: `Color(0.05, 0.1, 0.2, 0.85)` - Dark base
  - BlurOverlay: `Color(0.15, 0.2, 0.35, 0.6)` - Blur effect simulation
- Clean centered layout
- Large readable fonts
- Consistent button sizing

**Button Functions**:
- **게임 시작**: Loads main game scene (`res://scenes/main.tscn`)
- **설정**: Opens options menu (TODO: not implemented yet)
- **종료**: Quits the game

**Interaction**:
```gdscript
func _on_start_button_pressed() -> void:
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_button_pressed() -> void:
    get_tree().quit()
```

### Project Settings

**Startup Scene**: `project.godot`
```ini
run/main_scene="res://scenes/ui/title_screen.tscn"
```

The game now starts with the title screen instead of directly loading the main scene.

---

## 3) Difficulty Selector

**File**: `scenes/ui/difficulty_selector.tscn`
**Script**: Connected to terrain generation system

**Purpose**: Allows player to choose terrain difficulty before starting.

### UI Layout

```
VBoxContainer (top-center)
├─ Label "Select Difficulty"
├─ Button "Easy"
├─ Button "Medium"
├─ Button "Hard"
```

### Difficulty Effects

| Difficulty | Terrain Roughness | Vertical Drop | Path Width | Obstacles |
|------------|------------------|---------------|------------|-----------|
| **Easy** | 5-8m amplitude | 200m | 8m | 5-8 total |
| **Medium** | 10-15m amplitude | 350m | 5m | 15-20 total |
| **Hard** | 20-30m amplitude | 500m | 3m | 30-40 total |

### API

```gdscript
# Connect to terrain generator
difficulty_selector.difficulty_selected.connect(_on_difficulty_selected)

func _on_difficulty_selected(difficulty: String):
    # "easy", "medium", or "hard"
    terrain_generator.regenerate_with_difficulty(difficulty)
```

---

## 4) Obstacle Density Controls

**File**: `scripts/ui/density_controls.gd`
**Class**: `DensityControls` (extends VBoxContainer)
**Location**: Top-right corner, below minimap

**Purpose**: Real-time adjustment of obstacle density with player-proximity spawning.

### UI Layout

```
VBoxContainer (top-right, 20px margin)
├─ Label "Density"
├─ Button "Sparse" (toggle mode)
├─ Button "Normal" (toggle mode)
├─ Button "Dense" (toggle mode)
└─ Label (status: e.g., "10 near player\n(NORMAL)")
```

### Density Modes (Updated)

**All modes spawn obstacles near player (70m radius)**:

| Mode | Total Count | Distribution | Status Label |
|------|------------|--------------|--------------|
| **Sparse** | 2 | 30% tree, 40% grass, 30% rock | "2 obstacles\n(sparse)" |
| **Normal** | 10 | 30% tree, 40% grass, 30% rock | "10 near player\n(NORMAL)" |
| **Dense** | 20 | 30% tree, 40% grass, 30% rock | "20 obstacles\n(dense)" |

### Key Features

1. **Player-Proximity Spawning**:
   - All obstacles spawn within 70m radius of player
   - Exact count guaranteed (e.g., 10 in Normal mode)
   - Physics raycast-based terrain snapping

2. **Scene-Based Obstacles**:
   - Each obstacle is a StaticBody3D with collision
   - 3D labels for identification ("Tree", "Grass", "Rock (Small)")
   - Random rotation and scale (0.8-1.2x)

3. **Status Label**:
   - Shows current mode and obstacle count
   - Updates automatically on density change
   - Two-line format for readability

### Implementation

**Full Class** (`density_controls.gd`):

```gdscript
class_name DensityControls extends VBoxContainer

@export var obstacle_factory: ObstacleFactory

var sparse_button: Button
var normal_button: Button
var dense_button: Button
var status_label: Label
var current_mode := "normal"

func _ready() -> void:
    _create_buttons()
    _set_active_button("normal")

    if obstacle_factory:
        obstacle_factory.density_changed.connect(_on_density_changed)

    _update_status_label()

func _on_sparse_pressed() -> void:
    _set_density_mode("sparse")

func _on_normal_pressed() -> void:
    _set_density_mode("normal")

func _on_dense_pressed() -> void:
    _set_density_mode("dense")

func _set_density_mode(mode: String) -> void:
    if mode == current_mode:
        return

    current_mode = mode
    _set_active_button(mode)

    if obstacle_factory:
        obstacle_factory.set_obstacle_density(mode)

    _update_status_label()

func _update_status_label() -> void:
    match current_mode:
        "sparse":
            status_label.text = "2 obstacles\n(sparse)"
        "normal":
            status_label.text = "10 near player\n(NORMAL)"
        "dense":
            status_label.text = "20 obstacles\n(dense)"
```

### Signal Flow

```
User clicks button
    ↓
DensityControls._set_density_mode(mode)
    ↓
obstacle_factory.set_obstacle_density(mode)
    ↓
obstacle_factory.spawn_obstacles_near_player(count)
    ↓
obstacle_factory.density_changed signal emitted
    ↓
DensityControls._on_density_changed()
    ↓
_update_status_label() updates UI
```

### Visual Positioning

**Anchor**: Top-right corner
**Offset**:
- Left: -100px (from right edge)
- Top: 220px (below 180px minimap + 20px margin + 20px gap)
- Right: -20px (20px margin)
- Bottom: 340px

**Size**: 80×120 pixels (customizable)

---

## 5) Minimap System

**File**: `scripts/ui/minimap.gd`
**Class**: `Minimap` (extends Control)

**Purpose**: Provides top-down orthographic view showing player position, direction, and nearby obstacles.

### Features

1. **Real-time Player Tracking**
   - Camera follows player from above (150m height)
   - Smooth lerp follow (smoothing: 0.1)
   - Player arrow always centered

2. **Player Direction Indicator**
   - Red arrow pointing forward (not backward!)
   - Rotates to match player yaw
   - Size: 16×16 pixels

3. **Obstacle Visualization**
   - Trees/Rocks: Grey dots (4.0px radius) - **INCREASED for visibility**
   - Grass: Grey dots (2.5px radius) - **INCREASED for visibility**
   - Color: `Color(0.5, 0.5, 0.5, 0.8)` (grey with alpha)
   - Only shows obstacles within view radius
   - Supports both MultiMesh and scene-based obstacles

4. **Zoom System**
   - Zoom range: 0.5x - 2.0x
   - Default view radius: 120m
   - Adjustable at runtime

### Configuration

```gdscript
@export var player: Node3D
@export var obstacle_factory: Node3D
@export var minimap_size := Vector2(180, 180)
@export var view_radius := 120.0
@export var zoom_level := 1.0  # 0.5 - 2.0
```

### API

```gdscript
# Set visibility
minimap.set_minimap_visible(true)
minimap.toggle_visibility()

# Adjust zoom
minimap.set_minimap_zoom(1.5)
var current_zoom = minimap.get_zoom_level()

# Signals
minimap.minimap_visibility_changed.connect(_on_visibility_changed)
minimap.minimap_zoom_changed.connect(_on_zoom_changed)
```

### Visual Appearance

**Location**: Top-right corner (20px margin)
**Size**: 180×180 pixels (customizable)
**Background**: SubViewport with transparent or sky background
**Overlay**: Player arrow + obstacle dots

---

## 6) HUD (Heads-Up Display)

**Location**: Player scene UI layer (`scenes/player/player.tscn`)

### Components

#### Speed Label
```gdscript
# Display current speed
$UI/SpeedLabel.text = "속도: %.1f m/s" % current_speed
```

#### Camera Mode Label
```gdscript
# Show active camera mode
$UI/CameraModeLabel.text = "카메라: " + camera_mode_names[current_mode]
```

**Camera Mode Names**:
- `"3인칭 (뒤)"` - Third-person rear
- `"3인칭 (앞)"` - Third-person front
- `"1인칭"` - First-person
- `"프리 카메라"` - Free camera (inspection)

---

## 7) Scene Hierarchy Example

```
Main.tscn (Node3D)
├─ WorldEnvironment
├─ DirectionalLight3D ("Sun")
├─ ProceduralSlope
│   ├─ TerrainMesh (MeshInstance3D)
│   ├─ StaticBody3D (collision)
│   └─ ObstacleFactory
│       ├─ Trees (MultiMeshInstance3D)
│       ├─ Grass (MultiMeshInstance3D)
│       └─ Rocks (MultiMeshInstance3D)
├─ Player (CharacterBody3D)
│   ├─ Body (mesh nodes)
│   ├─ Cameras (3P rear/front, 1P, Free)
│   └─ UI (CanvasLayer)
│       ├─ CameraModeLabel
│       └─ SpeedLabel
├─ FreeCamera (backup inspection camera)
└─ UI (CanvasLayer)
    ├─ DifficultySelector
    ├─ Minimap
    └─ DensityControls
```

---

## 8) Styling & Theme

### Color Palette

**UI Elements**:
- Background panels: Semi-transparent dark `Color(0.1, 0.1, 0.1, 0.7)`
- Button normal: `Color(0.3, 0.3, 0.3, 0.9)`
- Button hover: `Color(0.4, 0.4, 0.4, 0.9)`
- Button active: `Color(0.2, 0.5, 0.8, 1.0)`
- Text: White `Color(1, 1, 1, 1)`

**Minimap**:
- Player arrow: Red `Color(1, 0, 0, 1)`
- Obstacles: Grey `Color(0.5, 0.5, 0.5, 0.8)`
- Terrain: Natural colors from 3D view

### Font Settings

**Default UI Font**:
- Size: 20px
- Weight: Normal
- Anti-aliasing: Enabled

---

## 9) Input Handling

### Camera Toggle
**Key**: F1 (or `toggle_camera` action)
**Effect**: Cycles through camera modes, updates label

### UI Interactions
**Mouse**: Click buttons for difficulty/density changes
**Keyboard**: Number keys 1-3 for quick density selection (optional)

---

## 10) Performance Considerations

**Minimap Optimization**:
- SubViewport renders at full resolution (180×180)
- Update mode: ALWAYS (real-time tracking)
- Obstacle dots drawn via Control.draw() (GPU-efficient)
- Only obstacles within view radius are drawn

**UI Update Frequency**:
- Speed label: Every frame (`_process`)
- Camera label: On camera change only
- Minimap: Every frame (smooth following)

---

## 10) Future Enhancements

### Planned Features

1. **Mission System UI**
   - Objective tracker
   - Timer display
   - Progress bar

2. **Settings Menu**
   - Graphics quality
   - Audio volume
   - Control remapping

3. **Pause Menu**
   - Resume/Restart/Quit
   - Quick settings access

4. **Score Display**
   - Time elapsed
   - Distance traveled
   - Tricks performed (future)

---

## 11) Troubleshooting

### Minimap not showing
- Verify `player` and `obstacle_factory` references are set
- Check minimap visibility: `minimap.visible = true`
- Ensure SubViewport is rendering: check render target update mode

### Player arrow pointing wrong direction
- Arrow texture should point UP in image (not down)
- Rotation calculation: `player_arrow.rotation = player.rotation.y`
- No offset needed if arrow texture is correctly oriented

### Obstacle dots not appearing
- Verify ObstacleFactory has MultiMesh instances populated
- Check obstacle positions are not underground (Y < -500 hidden)
- Ensure obstacles are within view radius

### Density buttons not working
- Check signal connections in `_ready()`
- Verify ObstacleFactory reference is valid
- Confirm `set_obstacle_density()` method exists

---

## 12) API Reference

### Minimap Class

```gdscript
class_name Minimap extends Control

# Exports
@export var player: Node3D
@export var obstacle_factory: Node3D
@export var minimap_size: Vector2
@export var view_radius: float
@export var zoom_level: float

# Methods
func set_minimap_visible(is_visible: bool) -> void
func set_minimap_zoom(mult: float) -> void
func get_zoom_level() -> float
func toggle_visibility() -> void

# Signals
signal minimap_visibility_changed(is_visible: bool)
signal minimap_zoom_changed(zoom_level: float)
```

### DensityControls Script

```gdscript
extends VBoxContainer

# Methods
func set_density(mode: String) -> void  # "sparse" | "normal" | "dense"
func get_current_density() -> String

# Signals
signal density_changed(mode: String)
```

---

## 13) Best Practices

**UI Organization**:
- Keep all UI scripts in `scripts/ui/`
- Scene files in `scenes/ui/`
- Use CanvasLayer for overlay UI (always on top)

**Signal Usage**:
- Prefer signals over direct method calls for decoupling
- Connect in `_ready()` function
- Use lambda functions for simple callbacks

**Performance**:
- Minimize `_process()` updates when possible
- Use signals for event-driven updates
- Cache references to frequently accessed nodes

**Accessibility**:
- Provide clear visual feedback for interactions
- Use consistent styling across all UI elements
- Ensure readable font sizes (minimum 16px)
