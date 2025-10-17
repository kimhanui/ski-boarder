# Player Animation Version Comparison

## V1 (Original) vs V2 (Enhanced)

This document compares the two player animation systems implemented in the ski-boarder game.

## Quick Summary

- **V1 (player.gd)**: Basic procedural animation with simple body tilts and ski stances
- **V2 (player_v2.gd)**: Enhanced animation based on PLAYER_MOVEMENT.md specifications with breathing cycles, arm swings, weight shifting, and ski edge effects

## How to Switch Versions

Currently, the project uses **V2** by default (`player.tscn` → `player_v2.gd`).

To switch back to V1:
1. Open `scenes/player/player.tscn`
2. Change line 3 from:
   ```
   [ext_resource type="Script" path="res://scripts/player/player_v2.gd" id="1_player_script"]
   ```
   to:
   ```
   [ext_resource type="Script" uid="uid://lf14tmup8yax" path="res://scripts/player/player.gd" id="1_player_script"]
   ```

## Feature Comparison

### IDLE Animation

| Feature | V1 | V2 |
|---------|----|----|
| Base stance | Upright (0°) | Athletic stance (-15°) |
| Breathing cycle | ❌ None | ✅ Torso ±3° (2s cycle) |
| Arm idle motion | ❌ Static | ✅ Subtle swing ±5° |
| Head movement | ❌ Static | ✅ Forward -0.02 on inhale |

**Visual Impact**: V2 looks more alive and natural even when standing still.

---

### Forward/Accelerate Animation

| Feature | V1 | V2 |
|---------|----|----|
| Torso lean | -45° static | -45° with breathing |
| Arm position | Static -45° | ✅ Push-glide cycle |
| Arm swing | ❌ None | ✅ Opposite phase swing |
| Push timing | N/A | ✅ 0.8s cycle (push→glide) |

**Arm Swing Details (V2)**:
- Left arm: -45° (push) → -30° (recover)
- Right arm: Opposite phase
- Creates realistic skiing pole motion

**Visual Impact**: V2 adds dynamic arm movement that matches real skiing technique.

---

### Turn Animation

| Feature | V1 | V2 |
|---------|----|----|
| Body tilt | ±30° roll | ✅ ±30° roll + weight shift |
| Weight shift (COM) | ❌ None | ✅ Torso ±0.03 lateral |
| Torso yaw | ❌ None | ✅ ±10° face into turn |
| Leg angles | ❌ Static | ✅ Weighted leg -6°, trail -3° |
| Ski yaw | ❌ None | ✅ ±12° at apex |
| Inner ski offset | ❌ None | ✅ +2° trail |
| Edge chatter | ❌ None | ✅ ±2° micro-vibration |

**Weight Shift Details (V2)**:
- Left turn: Weight on RIGHT leg → shift torso right (+0.03)
- Right turn: Weight on LEFT leg → shift torso left (-0.03)
- Torso rotates to face turn direction (±10°)

**Ski Edge Effect (V2)**:
- Both skis yaw into turn (±12°)
- Inner ski trails by additional 2°
- Micro-vibrations (±2°) simulate "edge chatter"

**Visual Impact**: V2 looks dramatically more realistic with proper weight shifting and ski carving.

---

### Brake Animation

| Feature | V1 | V2 |
|---------|----|----|
| Lean back | -15° | ✅ -20° (more pronounced) |
| Torso lean | 0° (upright) | ✅ -10° (slight forward) |
| Ski stance | Pizza/wedge | ✅ Enhanced pizza/wedge |
| Pole position | ❌ Static | ✅ Improved placement |

**Visual Impact**: V2 has more pronounced emergency stop stance.

---

### Skating Animation

| Feature | V1 | V2 |
|---------|----|----|
| Implementation | ✅ Implemented | ✅ Implemented (unchanged) |
| Push-glide cycle | ✅ Working | ✅ Working |

**Note**: Skating animation is identical in both versions (works well in V1).

---

## Technical Differences

### Code Structure

**V1 (player.gd)**:
- Simple state variables (`current_tilt`, `current_lean`, `current_upper_lean`)
- Direct application of rotations
- ~379 lines

**V2 (player_v2.gd)**:
- Additional animation phases (`breathing_phase`, `arm_swing_phase`, `edge_chatter_phase`)
- Dedicated functions for each animation type
- Weight shifting and edge effects
- ~481 lines (+102 lines for enhanced features)

### New Functions in V2

```gdscript
_update_breathing_cycle(delta)     # IDLE breathing
_update_arm_swing(delta)            # Forward arm motion
_apply_weight_shift(turn, delta)    # Turn weight distribution
_reset_weight_shift(delta)          # Return to neutral
_apply_ski_edge_effect(turn, delta) # Ski carving effects
```

---

## Performance

Both versions have similar performance:
- V2 adds ~3 animation phases (breathing, arm swing, edge chatter)
- Additional calculations are minimal (sine waves, lerps)
- No noticeable FPS difference

---

## Recommendations

### Use V1 if:
- ✅ You want simpler, more arcade-style gameplay
- ✅ You prefer minimal animation complexity
- ✅ You need maximum performance (though difference is negligible)

### Use V2 if:
- ✅ You want realistic skiing animations
- ✅ You value visual polish and immersion
- ✅ You want to match PLAYER_MOVEMENT.md specifications
- ✅ You're building a simulation-focused game

---

## Implementation Notes

### PLAYER_MOVEMENT.md Compliance

V2 implements the following specs from PLAYER_MOVEMENT.md:

- ✅ **IDLE** (0): Breathing cycle with torso ±3°, arm idle ±5°
- ✅ **FORWARD** (1): Push-glide arm cycle with opposite phases
- ✅ **LEFT/RIGHT TURN** (2/3): COM shift, torso yaw, leg angles, ski edge
- ✅ **BRAKE** (4): Enhanced lean back and torso positioning
- ⚠️ **EMERGENCY STOP** (4b): Not yet implemented (double-tap brake)
- ⚠️ **JUMP** (5): Not yet implemented

### Keyframe vs Procedural

**PLAYER_MOVEMENT.md** specifies keyframe-based animations (for AnimationPlayer).

**V2** translates these into **procedural animations** using:
- Sine waves for cycles (breathing, arm swing, edge chatter)
- Lerp for smooth transitions
- Phase-based timing instead of fixed keyframes

This provides more responsive gameplay while maintaining the visual quality of keyframed animations.

---

## Visual Comparison Checklist

Test both versions to see the difference:

### IDLE (No Input)
- [ ] V1: Static upright stance
- [ ] V2: Gentle breathing, subtle arm sway, slight athletic crouch

### Forward (W Key)
- [ ] V1: Lean forward, static arms
- [ ] V2: Lean forward, arms swing in push-glide rhythm

### Turn Left/Right (A/D Keys)
- [ ] V1: Body tilts, simple rotation
- [ ] V2: Body tilts + weight shifts to opposite leg + skis carve with edge angles

### Brake (S Key)
- [ ] V1: Lean back -15°, pizza stance
- [ ] V2: Lean back -20°, enhanced pizza stance with forward torso balance

---

## Future Enhancements

Possible additions for V3:
- [ ] Emergency stop (double-tap S)
- [ ] Jump animation with crouch → takeoff → air → landing
- [ ] Pole plant effects during turns
- [ ] Variable animation speed based on slope steepness
- [ ] Head look-ahead during high-speed turns
- [ ] Dynamic arm angles based on turn sharpness

---

## Credits

- **V1**: Original implementation with core skiing mechanics
- **V2**: Enhanced based on PLAYER_MOVEMENT.md specifications
- **PLAYER_MOVEMENT.md**: Detailed animation specifications for low-poly ski character

---

Last updated: 2025-10-17
