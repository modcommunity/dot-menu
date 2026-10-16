class_name DotMenuFrameClock
extends RefCounted

## Wall-clock frame times, split into where each frame went: physics, script, render, and
## the wait before the next frame began.
##
## [codeblock]
## var clock := DotMenuFrameClock.new()
## clock.start(get_tree())
## # ... later, any number of frames on:
## var s := clock.summary(1.0)   # {fps, mean_ms, worst_ms, physics_ms, steps, ...}
## [/codeblock]
##
## [b]Why not the process delta.[/b] The delta [method Node._process] is handed is smoothed
## ([member ProjectSettings.application/run/delta_smoothing]) and clamped, so a 120 ms hitch
## arrives as a few frames of 30 and a steady 37 ms frame can read as 33. A frame graph built
## on it draws what the engine wished had happened. This reads [method Time.get_ticks_usec]
## at four points the engine already signals in every iteration of its main loop:
##
## - the first [signal SceneTree.physics_frame] of an iteration (the start of physics);
## - [signal SceneTree.process_frame] (physics over, scripts' [code]_process[/code] next);
## - [signal RenderingServer.frame_pre_draw] (scripts over, rendering next);
## - [signal RenderingServer.frame_post_draw] (the CPU side of rendering over).
##
## A frame's wall time is the gap between two iteration starts, which is what the player
## waits; [code]wait[/code] is what is left after the three measured parts: the frame cap,
## vsync, and in a browser the wait for the next animation frame and for the GPU. A browser
## frame that needs 17 ms of work waits for the second vsync, so a frame whose parts add up
## to 18 ms and whose wall time is 33 ms is not mysterious: it is the wait column.
##
## [b]Engine.get_monitor's TIME_PROCESS and TIME_PHYSICS_PROCESS are not per-frame
## figures.[/b] They are the slowest frame of the last second, refreshed once a second, so
## a benchmark that averaged them reported each second's worst frame as its typical one.
##
## Headless there is no draw, so the script part runs to the next iteration and render is 0.

## Frames kept, at the frame rate: four seconds at 240 fps, sixteen at 60.
const KEPT := 960

## A frame this long is a hitch: three frames at 60 fps, a visible stall.
const HITCH_MS := 50.0

## Seconds a hitch is remembered for [method summary]'s count.
const HITCH_WINDOW_SEC := 60.0

var _tree: SceneTree = null
var _running := false

# The iteration being timed. Microseconds; 0 is "not seen this iteration".
var _iter_start := 0
var _phys_start := 0
var _steps := 0
var _script_start := 0
var _pre_draw := 0
var _physics_us := 0
var _script_us := 0
var _render_us := 0
var _in_iter := false

# The finished frames, a ring: when each began, and its parts.
var _at := PackedInt64Array()
var _wall := PackedInt32Array()
var _phys := PackedInt32Array()
var _script := PackedInt32Array()
var _render := PackedInt32Array()
var _step_n := PackedByteArray()
var _head := 0
var _count := 0
var _total_frames := 0

var _hitches := PackedInt64Array()
var _worst_hitch_ms := 0.0

## Called once per finished frame with ([code]wall_us, physics_us, script_us, render_us,
## steps[/code]), for a graph that keeps its own buckets.
var on_frame: Callable = Callable()


func _init() -> void:
	# One by one: a packed array in a loop variable is a copy, and resizing it grows nothing.
	var _r := _at.resize(KEPT)
	_r = _wall.resize(KEPT)
	_r = _phys.resize(KEPT)
	_r = _script.resize(KEPT)
	_r = _render.resize(KEPT)
	_r = _step_n.resize(KEPT)


## Starts timing [param tree]'s frames. Costs four signal callbacks a frame; [method stop]
## when nothing reads it.
func start(tree: SceneTree) -> void:
	if _running or tree == null:
		return
	_tree = tree
	_running = true
	_in_iter = false
	_iter_start = 0
	var _a := tree.physics_frame.connect(_on_physics)
	var _b := tree.process_frame.connect(_on_process)
	var _c := RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	var _d := RenderingServer.frame_post_draw.connect(_on_post_draw)


func stop() -> void:
	if not _running:
		return
	_running = false
	if is_instance_valid(_tree):
		if _tree.physics_frame.is_connected(_on_physics):
			_tree.physics_frame.disconnect(_on_physics)
		if _tree.process_frame.is_connected(_on_process):
			_tree.process_frame.disconnect(_on_process)
	if RenderingServer.frame_pre_draw.is_connected(_on_pre_draw):
		RenderingServer.frame_pre_draw.disconnect(_on_pre_draw)
	if RenderingServer.frame_post_draw.is_connected(_on_post_draw):
		RenderingServer.frame_post_draw.disconnect(_on_post_draw)
	_tree = null


func is_running() -> bool:
	return _running


## Forgets every frame.
func reset() -> void:
	_head = 0
	_count = 0
	_hitches.clear()
	_worst_hitch_ms = 0.0
	_iter_start = 0
	_in_iter = false


func _begin(now: int) -> void:
	if _iter_start != 0:
		# The last iteration closes when this one opens: its wall time is the gap, and a
		# draw that never came (headless) leaves the script part running to here.
		if _script_start != 0 and _pre_draw == 0:
			_script_us = now - _script_start
		_finish(now - _iter_start)
	_iter_start = now
	_in_iter = true
	_phys_start = 0
	_steps = 0
	_script_start = 0
	_pre_draw = 0
	_physics_us = 0
	_script_us = 0
	_render_us = 0


func _finish(wall_us: int) -> void:
	_at[_head] = _iter_start
	_wall[_head] = wall_us
	_phys[_head] = _physics_us
	_script[_head] = _script_us
	_render[_head] = _render_us
	_step_n[_head] = mini(_steps, 255)
	_head = (_head + 1) % KEPT
	_count = mini(_count + 1, KEPT)
	_total_frames += 1
	var ms := float(wall_us) / 1000.0
	if ms >= HITCH_MS:
		_hitches.append(_iter_start)
		_worst_hitch_ms = maxf(_worst_hitch_ms, ms)
	if on_frame.is_valid():
		on_frame.call(wall_us, _physics_us, _script_us, _render_us, _steps)


func _on_physics() -> void:
	var now := Time.get_ticks_usec()
	# Physics after the last process frame is the next iteration.
	if not _in_iter or _script_start != 0:
		_begin(now)
	if _phys_start == 0:
		_phys_start = now
	_steps += 1


func _on_process() -> void:
	var now := Time.get_ticks_usec()
	# A second process frame with no physics between is an iteration that ran no step.
	if not _in_iter or _script_start != 0:
		_begin(now)
	if _phys_start != 0:
		_physics_us = now - _phys_start
	_script_start = now


func _on_pre_draw() -> void:
	var now := Time.get_ticks_usec()
	if _script_start != 0:
		_script_us = now - _script_start
	_pre_draw = now


func _on_post_draw() -> void:
	var now := Time.get_ticks_usec()
	if _pre_draw != 0:
		_render_us = now - _pre_draw
	# The next physics or process signal opens the next iteration. Headless this never
	# comes, which is why those two also open one after a process frame.
	_in_iter = false


## Frames timed since [method start], for a benchmark to difference.
func total_frames() -> int:
	return _total_frames


## The frames of the last [param seconds]: [code]frames, fps, mean_ms, worst_ms, p50_ms,
## p95_ms[/code], the mean parts [code]physics_ms, script_ms, render_ms, wait_ms[/code],
## [code]steps[/code] (physics steps a frame), and [code]hitches[/code] (frames of
## [constant HITCH_MS] or more in the last [constant HITCH_WINDOW_SEC]) with
## [code]worst_hitch_ms[/code] since the last [method reset].
func summary(seconds: float = 1.0) -> Dictionary:
	var since := Time.get_ticks_usec() - int(seconds * 1e6)
	var n := 0
	var wall := 0
	var worst := 0
	var phys := 0
	var script := 0
	var render := 0
	var steps := 0
	var walls := PackedInt32Array()
	for k in _count:
		var i := (_head - 1 - k + KEPT) % KEPT
		if _at[i] < since:
			break
		n += 1
		wall += _wall[i]
		worst = maxi(worst, _wall[i])
		phys += _phys[i]
		script += _script[i]
		render += _render[i]
		steps += _step_n[i]
		var _r := walls.append(_wall[i])
	var cut := Time.get_ticks_usec() - int(HITCH_WINDOW_SEC * 1e6)
	while not _hitches.is_empty() and _hitches[0] < cut:
		_hitches.remove_at(0)
	var out := {
		"frames": n, "fps": 0.0, "mean_ms": 0.0, "worst_ms": 0.0, "p50_ms": 0.0, "p95_ms": 0.0,
		"physics_ms": 0.0, "script_ms": 0.0, "render_ms": 0.0, "wait_ms": 0.0, "steps": 0.0,
		"hitches": _hitches.size(), "worst_hitch_ms": _worst_hitch_ms,
	}
	if n == 0:
		return out
	walls.sort()
	var fn := float(n)
	out["fps"] = fn / (float(wall) / 1e6)
	out["mean_ms"] = float(wall) / fn / 1000.0
	out["worst_ms"] = float(worst) / 1000.0
	out["p50_ms"] = float(walls[n / 2]) / 1000.0
	out["p95_ms"] = float(walls[mini(n - 1, int(fn * 0.95))]) / 1000.0
	out["physics_ms"] = float(phys) / fn / 1000.0
	out["script_ms"] = float(script) / fn / 1000.0
	out["render_ms"] = float(render) / fn / 1000.0
	out["wait_ms"] = maxf(0.0, float(wall - phys - script - render) / fn / 1000.0)
	out["steps"] = float(steps) / fn
	return out


func describe() -> Dictionary:
	var d := summary(1.0)
	d["running"] = _running
	d["total_frames"] = _total_frames
	return d
