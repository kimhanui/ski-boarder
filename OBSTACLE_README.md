# Obstacle Generation Documentation

This directory contains comprehensive analysis of how obstacles are generated in V1 and V2 terrain.

## Files in This Analysis

### Start Here
- **OBSTACLE_SUMMARY.md** - Quick summary with TL;DR, root causes, and recommended fixes
- **OBSTACLE_COMPARISON.txt** - Visual flow diagrams showing V1 vs V2 differences

### Detailed Analysis
- **OBSTACLE_ANALYSIS.md** - Complete breakdown with code sections, problems, and solutions
- **OBSTACLE_FILE_LOCATIONS.md** - All file paths and line-by-line code locations

### Related (Pre-existing)
- **OBSTACLES.md** - Original obstacle documentation (if it exists)

---

## Quick Summary

### V1 Terrain (Working)
- Obstacles created during terrain generation
- Method: `TerrainGenerator._generate_procedural_obstacles()` + `_build_obstacles()`
- Files: `/scripts/terrain/terrain_generator.gd` (lines 563-606, 419-476)
- Status: OBSTACLES VISIBLE

### V2 Terrain (Not Working)
- No obstacles in `TerrainGeneratorV2.create_flat_terrain()`
- Relies on `ObstacleFactory.spawn_obstacles_near_player()`
- File: `/scripts/terrain/obstacle_factory.gd` (lines 422-500)
- Problem: Player reference is null at initialization time
- Status: NO OBSTACLES

---

## Key Findings

### Why V1 Works
1. Obstacles created as part of terrain generation
2. No player dependency
3. Deterministic (always executes)
4. Guaranteed to render

### Why V2 Fails
1. TerrainGeneratorV2 doesn't generate obstacles
2. Relies on separate system (ObstacleFactory)
3. ObstacleFactory depends on player reference
4. Player not available at initialization time
5. Function exits early: `if not player: return`

### Root Cause Files
- **MISSING**: TerrainGeneratorV2 obstacle generation
  - File: `/scripts/terrain/terrain_generator_v2.gd`
  - Should: Generate obstacles like V1 does
  
- **PROBLEM**: ObstacleFactory timing
  - File: `/scenes/environment/procedural_slope.gd` (line 33-36)
  - Should: Wait for player before spawning obstacles

- **PROBLEM**: ObstacleFactory player check
  - File: `/scripts/terrain/obstacle_factory.gd` (lines 335-339, 422-443)
  - Should: Have fallback or wait for player

---

## Recommended Solutions (in order)

### BEST: Add V2 Obstacle Generation
- Mirror V1's `_generate_procedural_obstacles()` approach
- Add to `TerrainGeneratorV2.create_flat_terrain()`
- Account for 20° slope angle
- File to modify: `/scripts/terrain/terrain_generator_v2.gd`

### GOOD: Fix Timing in ProceduralSlope
- Wait for player to be ready
- Then call `set_obstacle_density()`
- File to modify: `/scenes/environment/procedural_slope.gd`

### OKAY: Use Test Mode Approach
- Adapt `_create_test_obstacles_fixed()` logic
- Fixed positions (no player dependency)
- File to modify: `/scripts/terrain/obstacle_factory.gd`

### QUICK: Add Fallback Spawning
- Use fixed spawn positions if player not found
- File to modify: `/scripts/terrain/obstacle_factory.gd`

---

## Code Locations

### V1 Obstacle Generation (WORKING)
```
File: /scripts/terrain/terrain_generator.gd
Lines 563-606: _generate_procedural_obstacles()
Lines 419-476: _build_obstacles()
```

### V2 Obstacle Generation (MISSING)
```
File: /scripts/terrain/terrain_generator_v2.gd
Lines 14-65: create_flat_terrain()
  ✗ Does NOT generate obstacles
```

### ObstacleFactory Player Check (PROBLEM)
```
File: /scripts/terrain/obstacle_factory.gd
Lines 335-339: _find_player()
Lines 422-500: spawn_obstacles_near_player()
  ✗ Exits early if player is null
```

### ProceduralSlope Initialization (TIMING ISSUE)
```
File: /scenes/environment/procedural_slope.gd
Lines 33-36: Tries to init ObstacleFactory
  ⚠ Player may not be ready yet
```

---

## Testing Evidence

### V1: WORKING
- Switch to V1 terrain in game
- Obstacles visible on procedural terrain
- Console: No warnings about missing player

### V2: NOT WORKING
- Switch to V2 terrain in game
- No obstacles visible
- Console: "[ObstacleFactory] No player found, cannot spawn near player"

### Test Mode: REFERENCE
- Obstacles spawn correctly (procedural_slope.gd:272-313)
- Uses fixed positions (no player dependency)
- Proves V2 CAN display obstacles with right approach

---

## File Structure

```
/scripts/terrain/
├── terrain_generator.gd        ✓ Has obstacle generation
├── terrain_generator_v2.gd     ✗ Missing obstacle generation
├── obstacle_factory.gd         ⚠ Player dependency issue
├── difficulty_config.gd        (provides obstacle config)
└── ...

/scenes/environment/
├── procedural_slope.gd         ⚠ Timing issue with initialization
├── procedural_slope.tscn       (scene structure)
└── ...
```

---

## How to Use This Documentation

1. **Quick Overview**: Read `OBSTACLE_SUMMARY.md`
2. **Understand Differences**: Look at `OBSTACLE_COMPARISON.txt` diagrams
3. **Detailed Analysis**: Review `OBSTACLE_ANALYSIS.md` code sections
4. **Find Specific Locations**: Check `OBSTACLE_FILE_LOCATIONS.md` line numbers
5. **Implement Fix**: Choose recommended solution and modify files

---

## Questions to Ask

- **Why are V1 obstacles visible?** 
  - Because they're created during terrain generation (guaranteed)

- **Why are V2 obstacles missing?**
  - Because TerrainGeneratorV2 doesn't generate them, and ObstacleFactory needs player reference

- **Can V2 obstacles be fixed?**
  - Yes, see "Recommended Solutions" above

- **Which fix is best?**
  - Adding V2 obstacle generation (Option 1) - mirrors proven V1 approach

- **How do test obstacles work?**
  - Use fixed positions and proper height calculations (no player dependency)

---

## Related Files to Review

- `/scripts/terrain/terrain_generator.gd` - V1 obstacle generation (reference)
- `/scripts/terrain/terrain_generator_v2.gd` - V2 terrain (needs obstacles)
- `/scripts/terrain/obstacle_factory.gd` - Dynamic obstacle spawner (timing issue)
- `/scenes/environment/procedural_slope.gd` - Terrain coordinator (initialization)
- `/scripts/terrain/difficulty_config.gd` - Obstacle configuration

---

## Summary

V1 obstacles work because they're created during terrain generation. V2 obstacles don't work because TerrainGeneratorV2 doesn't generate them, and the fallback system (ObstacleFactory) has a timing issue with player references. The recommended fix is to add obstacle generation to TerrainGeneratorV2, mirroring the proven V1 approach.

For detailed information, see the individual documentation files listed above.
