# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot game project for a ski-boarder game. The project is currently in initial setup phase.

## Development Commands

### Running the Game
```bash
# Open the project in Godot editor
godot --editor --path .

# Run the game directly
godot --path .

# Run a specific scene
godot --path . --scene path/to/scene.tscn
```

### Building/Exporting
```bash
# Export for a specific platform (requires export preset configured)
godot --export "Platform Name" output_path

# Headless export (no editor window)
godot --headless --export "Platform Name" output_path
```

### Testing
GDScript testing typically uses GUT (Godot Unit Test) or gdUnit4:
```bash
# If using GUT (once installed)
godot --path . -s addons/gut/gut_cmdln.gd

# If using gdUnit4 (once installed)
godot --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd
```

## Godot Project Structure

### Scene Organization
- **scenes/**: Main game scenes (.tscn files)
  - Organize by feature/level (e.g., scenes/levels/, scenes/ui/, scenes/player/)

### Script Organization
- **scripts/**: GDScript files (.gd)
  - Should mirror scene organization
  - Global scripts/autoloads typically in scripts/autoload/

### Resource Organization
- **assets/**: Game assets
  - **sprites/**: 2D sprites and textures
  - **models/**: 3D models and meshes
  - **audio/**: Sound effects and music
  - **fonts/**: Font files

- **resources/**: Godot resource files (.tres)
  - Reusable resources like materials, animations, themes

## Key Godot Concepts for This Project

### Node Structure
Godot uses a tree-based node system. Common nodes for a ski-boarder game:
- **CharacterBody2D/3D**: For the player ski-boarder with physics
- **Area2D/3D**: For triggers and collectibles
- **TileMap**: For terrain/slopes (2D)
- **MeshInstance3D**: For terrain (3D)
- **Camera2D/3D**: For following the player

### Signals
Godot's observer pattern for decoupled communication between nodes. Define signals at the top of scripts:
```gdscript
signal player_crashed
signal trick_completed(trick_name, score)
```

### Autoloads (Singletons)
Global scripts accessible from anywhere, defined in project.godot. Typical uses:
- Game state management
- Score/progress tracking
- Audio management
- Scene transition handling

### Physics and Movement
- Use `_physics_process(delta)` for player movement and physics
- CharacterBody2D/3D provides `move_and_slide()` for collision-aware movement
- Consider gravity, acceleration, and momentum for ski physics

## GDScript Conventions

### File Structure
```gdscript
extends NodeType  # or class_name ClassName

# Signals
signal signal_name

# Constants
const CONSTANT_NAME = value

# Exported variables (appear in editor)
@export var variable_name: Type = default_value

# Public variables
var public_variable: Type

# Private variables (prefix with _)
var _private_variable: Type

# Onready variables (initialized when node is ready)
@onready var _node_ref = $NodePath

# Built-in callbacks
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

func _physics_process(delta: float) -> void:
    pass

# Public methods
func public_method() -> void:
    pass

# Private methods
func _private_method() -> void:
    pass
```

### Naming Conventions
- Files: snake_case.gd (e.g., player_controller.gd)
- Classes: PascalCase (e.g., PlayerController)
- Variables/functions: snake_case (e.g., jump_force, calculate_speed())
- Constants: SCREAMING_SNAKE_CASE (e.g., MAX_SPEED)
- Private members: prefix with underscore (e.g., _internal_state)
- Signals: past tense, snake_case (e.g., health_changed, enemy_died)

## Project Configuration

The project.godot file contains:
- Project settings and metadata
- Autoload configurations
- Input mappings
- Display/rendering settings
- Physics layer names

Always check project.godot for input action names when implementing controls.

## Godot Version

Check the `config_version` and `features` in project.godot to determine the Godot version. GDScript syntax varies between Godot 3.x and 4.x:
- Godot 4.x uses `@export`, `@onready`, `@tool` annotations
- Godot 3.x uses `export`, `onready`, `tool` keywords
