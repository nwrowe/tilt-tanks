extends RefCounted
class_name GameMode

const HOTSEAT: int = 0
const SINGLE_PLAYER_TURN_AI: int = 1
const SINGLE_PLAYER_REALTIME: int = 2

static func is_realtime(mode: int) -> bool:
	return mode == SINGLE_PLAYER_REALTIME

static func is_hotseat(mode: int) -> bool:
	return mode == HOTSEAT
