extends RefCounted

## The scoreboard's height cap and scroll, run from menu_selftest (kept out of it to hold its size baseline).


static func run(host: Node) -> void:
	host._section("The scoreboard caps its height and scrolls the rows")
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.disable_3d = true
	host.add_child(vp)
	var board := DotMenuScoreboard.new()
	vp.add_child(board)
	var rows: Array = []
	for i in range(15):
		rows.append({"name": "P%d" % i, "score": i, "seconds": 60, "ping": 30})
	board.source = func() -> Dictionary: return {"server": {"name": "S"}, "players": rows}
	board.open()
	for i in 3:
		await host.get_tree().process_frame
	var window := board.find_child("Window", true, false) as Control
	var scroll := board.find_child("Scroll", true, false) as ScrollContainer
	var cap := 720.0 * DotMenuScoreboard.MAX_HEIGHT_FRACTION
	host._check(scroll != null and window != null and scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
		"the rows sit in a vertical-only scroll container")
	host._check(window != null and window.size.y <= cap + 1.0, "15 rows at 720 high: panel %.0f <= cap %.0f" % [window.size.y, cap])
	host._check(scroll != null and scroll.get_child(0).get_combined_minimum_size().y > scroll.size.y + 1.0, "and the rows past it scroll")
	rows.resize(4)
	board.redraw()
	for i in 3:
		await host.get_tree().process_frame
	host._check(scroll.size.y >= scroll.get_child(0).get_combined_minimum_size().y - 1.0, "rows that fit are not clipped")
	vp.queue_free()
