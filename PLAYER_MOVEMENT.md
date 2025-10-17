You are generating game-ready skiing animations for a LOW-POLY character in Godot 4.

## Rig & Constraints (must follow exactly)
- Node hierarchy:
  Body (root)
    ├─ Head
    ├─ Torso
    ├─ LeftArm
    ├─ RightArm
    ├─ LeftLeg
    ├─ RightLeg
    └─ (Skis are children of Legs: Skis are at Y = -0.7 relative to Legs; global ≈ -1.0)
- Eyes are a child of Head.
- Y positions (relative): Head 0.65, Arms 0.3, Torso 0.15, Legs -0.3, Skis -0.7 (from Legs).
- Upper body group = Head, Torso, LeftArm, RightArm.
- Lower body group = LeftLeg, RightLeg (+Skis).
- Current rules:
  - Forward (↑) baseline: Torso & Arms rotate X = -45° (local); Head does NOT rotate (translation only); Legs are upright at idle.
- Keep transforms local to each node.
- Keep Head rotation = 0 at all times; allow small forward translation only.
- Preserve the existing relative Y offsets (do not reorder or re-parent).

## Style & Delivery
- Low-poly, blocky character; subtle secondary motion.
- 30 FPS. Provide keyframes (frame#: node: {rotationXYZ°, translationXYZ}).
- Each clip length: 24–32 frames (0.8–1.1s) and loopable where noted.
- Provide easing (easeInOut, easeOut) per segment.
- Output format:
  1) High-level description (what player sees)
  2) Technical notes (body mechanics)
  3) Keyframe table per node (frames & transforms)
  4) Blend hints (how to blend with other clips)

## Clips to produce

### 0) IDLE (baseline, loopable, 24f)
- Look: Soft athletic stance. Slight knee bend. Poles lightly contact snow.
- Tech:
  - Torso X = -15° (not -45°), small breathing cycle ±3°.
  - Arms swing idle ±5° on X; poles vertical.
  - Head: translate Z = -0.02 (forward) on inhale; no rotation.
  - Legs: slight bend; Skis parallel, shoulder-width.
- Blend target: base layer for all actions.

### 1) FORWARD / ACCELERATE (↑, loopable, 24f)
- Look: Glide with gentle push.
- Tech deltas (from IDLE mid-pose):
  - Torso: X = -45°; small sine ±3°.
  - LeftArm/RightArm: X = -45° (push) then recover to -30°; slight opposite phase.
  - Head: translate Z = -0.03 on push; Y wobble ±0.01 for terrain.
  - Legs: bend more on push (knees down 3–5°), then return.
  - Skis: parallel, minor toe-in/out wobble ±2° on Z for “edge chatter”.
- Loop cadence: push at f0→f8, glide f8→f24.
- Provide 24f keyframe tables.

### 2) LEFT TURN (←, loopable carve, 28f)
- Look: Carving left; COM shifts to right leg.
- Tech:
  - Weight: shift hips over RightLeg by translating Torso X = +0.03 (to right) while Torso rotates Y = -10° (facing turn).
  - Torso X maintain ≈ -35° to -40°.
  - LeftArm plants slightly: LeftArm Z = -8° roll; RightArm balances Z = +6°.
  - Legs:
    - RightLeg: edges more; rotate Z = -6° (edge), slight knee flex.
    - LeftLeg: trails; Z = -3°; a bit more extension.
  - Skis: yaw to the left: both Skis Yaw (Y) = -12° at apex; inner (left) ski trails by -2° extra.
- Apex at f14; entry f0→f14, exit f14→f28 (loopable S-curve).
- Provide 28f keyframe tables.

### 3) RIGHT TURN (→, loopable carve, 28f)
- Mirror of LEFT TURN:
  - COM over LeftLeg, Torso Y = +10°, Torso X = -35° to -40°.
  - RightArm plants; LeftArm balances.
  - Skis yaw Y = +12° at apex; inner (right) ski trails +2°.
- Provide mirrored keyframes.

### 4) BRAKE (↓, snowplow “A”, non-loop pose-to-hold, 24f)
- Look: Snowplow stop. **Front tips close; tails wide (clear “A”)**.
- Tech:
  - Legs abduct: both legs translate X outward ±0.02–0.03.
  - Skis: toe-in (tips meet), tail-out:
      * LeftSki Yaw (Y) = +14°; RightSki Yaw (Y) = -14° at f16, hold to f24.
  - Torso: lean back to X = -20°; slight Yaw oppose turn noise ±2°.
  - Arms: bring poles slightly forward for balance (X = -20°).
  - Head: translate Z = -0.015; no rotation.
- Timing: enter f0→f16, hold f16→f24 (can sustain).

### 4b) EMERGENCY STOP (↓ long press, parallel skid, 20f)
- Look: Sudden stop by twisting both skis to the RIGHT while close together.
- Tech:
  - Skis: parallel, gap = small (boots width), both Yaw (Y) = +22° by f10, hold to f20.
  - Torso: counter-rotate Y = -8°; X = -25° (lean back more).
  - Legs: deeper flex; quick COM drop 0.02 on Y at f8, rebound at f16.
  - Poles: stab behind (X = -35°) with slight drag.
- Use when user taps ↓ twice.

### 5) JUMP (contextual, 22f)
- Look: Pop jump, parallel skis, soft landing.
- Tech:
  - Crouch: f0→f6 (knees bend; Torso X = -50°, Arms sweep back to X = -55°).
  - Takeoff: f6→f10 (extend; Torso X = -35°; Arms swing slightly forward).
  - Air: f10→f16 (still, Skis parallel; micro toe-up Roll Z = +3°).
  - Land: f16→f22 (knees absorb; Torso briefly X = -55° then settle).
- Head: translate Z forward on takeoff (0.02), up on air (Y +0.02), back to baseline on land.

## Keyframe Table EXAMPLE FORMAT (fill similarly for every clip)
- Frame numbers assume 30 FPS.
- Rotations in degrees; XYZ order = (X pitch, Y yaw, Z roll). Local space per node.

Example (FORWARD, subset):
f0:
  Torso:   rot(-45, 0, 0)
  LeftArm: rot(-45, 0, 0)
  RightArm:rot(-30, 0, 0)
  Head:    pos(0, 0, -0.02)
  LeftLeg: rot(0, 0, 0)
  RightLeg:rot(0, 0, 0)
  Skis:    yaw(0/0), roll(0/0)
f8:
  Torso:   rot(-42, 0, 0)
  LeftArm: rot(-30, 0, 0)
  RightArm:rot(-45, 0, 0)
  Head:    pos(0, 0, -0.03)
...
f24: (loop to f0 smoothly)

## Blending & Layers
- Base layer: IDLE.
- Additive layer: small torso/arm noise and ski chatter (±2–3°).
- 2D BlendSpace:
  - X axis: TurnLeft (←) ↔ TurnRight (→)
  - Y axis: Speed (IDLE ↔ FORWARD)
  - Brake overrides on ↓, with higher priority; EmergencyStop on double-tap ↓.
- Transitions:
  - Idle→Forward: 6f easeOut.
  - Forward→Turn: 8f easeInOut; maintain speed layer.
  - Turn↔Turn: 6f crossfade via center.
  - Any→Brake: 4f snap; Brake hold loop permitted.
  - Any→EmergencyStop: 2f snap, 6f recoil.
  - Airborne (Jump) masks lower-body IK to keep skis parallel.

## Output
Provide:
1) Human-readable description for each clip,
2) Full keyframe tables for all nodes that move (Body optional if unchanged),
3) Notes on easing per segment,
4) Short Godot import notes (loop flags for Forward/Turns/Idle; hold for Brake; root motion off).
