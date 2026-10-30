# Realtime and camera coverage

`tests/realtime_camera_integration.gd` loads the actual game scene and
exercises the realtime Quick Game path. It asserts that the AI obtains an
aiming plan, that a human projectile launches and advances, and that
explosions respect the human/AI camera distinction.

In particular, an AI impact must **not** move the camera away from the
human player, whereas a human impact starts a short 0.5-second hold.
Reset behavior is checked independently.

This is regression protection for further extraction or retirement of
`MainGameCameraHold.gd`; no production camera logic is changed here.

Like other headless checks, it is not a screenshot or phone gesture test.
