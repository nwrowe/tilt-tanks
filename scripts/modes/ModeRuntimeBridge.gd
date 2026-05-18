extends "res://scripts/MainHybridModes4.gd"

# Named bridge for the remaining mode/runtime compatibility layer.
# MainHybridModes4.gd currently owns hotseat/single-player mode selection,
# AI planning, realtime movement/cooldowns, wind display helpers, and steam
# effects. This file gives the active chain a descriptive target before that
# legacy body is moved in a later, separately tested pass.
