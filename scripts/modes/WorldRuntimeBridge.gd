extends "res://scripts/MainHybridModes12.gd"

# Named bridge for the remaining world/runtime compatibility layer.
# MainHybridModes12.gd currently owns terrain/water/snow constants, realtime
# fire-charge state, the main in-game draw composition, and movement helpers.
# This file gives the active chain a descriptive target before the legacy body
# is moved in a later, separately tested pass.
