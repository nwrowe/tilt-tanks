# Remaining inheritance retirement plan

The active `scenes/Main.tscn` script chain is **14 scripts deep**
after retiring the realtime AI aiming and level-definition facades.
The exact chain is printed on every CI run by
`tests/check_inheritance_depth.py`. It fails if a PR expands the
hierarchy above 14. Lower the budget each time another layer retires.

## Next retirements, in order

### 1. MatchRuntimeBridge.gd — 171 lines, moderate risk
This bridge has already relinquished damage calculation and most direct
MatchState writes to MatchController. It is the strongest next candidate.
Extract state synchronization and adapters into a composed
`MatchRuntimeSynchronizer` (or another clearly named RefCounted object)
that owns MatchController/MatchState references and accepts typed runtime
data. Move only the small `reset_match`, turn-advance, explosion and
projectile hooks into the existing `MainGame.gd`; then repoint it
directly to `WeaponDefinitionRuntimeBridge.gd`. Keep side-effect order
and hotseat/AI callbacks unchanged. Add tests for full shot-to-next-turn,
dual defeat and reset before deleting the bridge. Target depth **13**.

### 2. WeaponDefinitionRuntimeBridge.gd — 111 lines, moderate risk
A data-driven WeaponRegistry and WeaponSplitLogic already exist. Extract
loadout and display lookup ownership to a `WeaponDefinitionSession` and
keep only unavoidable menu/projectile hooks on the weapon runtime.
Protect standard/heavy/cluster, restricted level loadouts and special
weapon families first. Target depth **12**.

### 3. MainWithMenus.gd — 250 lines, higher risk
Refactor remaining menu construction into independent UI views and
signals (as with CampaignMapView and TankGarageView), then move the
remaining navigation callbacks to a small coordinating node. Avoid
merging its entire body into ModeRuntimeBridge.

### 4. MainStablePowerPercent.gd / MainStableTweaks.gd — 135 / 206 lines
These are old overrides of the Node2D baseline. Separate input-to-aim
conversion, movement policy, and terrain/world settings into
standalone collaborators before bypassing them. Avoid moving all their
methods into the already-large Main.gd.

### Later: online and special-weapons facades
`MainGameOnlineHostWaitingFacade.gd` and
`MainGameProgressionFacade.gd` still contain live Godot RPC endpoints
and orchestration. Their removal requires an explicit network coordinator,
stable node paths for RPCs, and broader host/guest tests.
`MainGameSpecialWeaponsFacade.gd` should be split into weapon behavior
components rather than flattened into a parent.
`MainGame.gd` is also oversized and will ultimately need a much smaller
composed game root.

## Non-negotiable migration rules

1. Only remove a layer once its state has a clear owning component.
2. Preserve virtual method dispatch and `super` side-effect ordering.
3. Keep an independently reviewable PR per layer or isolated behavior.
4. Require Godot import, strict runtime-log checks, local gameplay,
   realtime/camera and actual two-process ENet tests.
5. Never interpret a passing headless suite as proof of Android sensor,
   UI layout or WAN latency behavior.

The immediate goal is not a shorter stack at any cost: it is a set of
small explicit game systems whose behaviors can be tested separately.
