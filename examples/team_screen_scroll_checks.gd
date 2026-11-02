extends RefCounted

## 40 teams on the team screen: every card exists, the area scrolls, focus follows. Run from menu_selftest.


static func run(host: Node) -> void:
	host._section("The team screen wraps and scrolls any number of teams")
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.disable_3d = true
	host.add_child(vp)
	var screen := DotMenuTeamScreen.new()
	vp.add_child(screen)
	var teams: Array = []
	for i in range(40):
		teams.append({"id": i + 1, "name": "Team %d" % (i + 1), "colour": "", "count": 0, "max": 0, "closed": "", "current": false})
	screen.open({"teams": teams, "ffa": false, "spectate_ok": true})
	for i in 4:
		await host.get_tree().process_frame
	var grid := screen.find_child("Cards", true, false) as GridContainer
	var scroll := screen.find_child("Scroll", true, false) as ScrollContainer
	host._check(grid != null and grid.get_child_count() == 41, "40 teams and Spectate make 41 cards")
	host._check(scroll != null and grid.columns * 202 <= 1280 * 0.9, "the columns fit the width (%d)" % grid.columns)
	host._check(scroll.size.y <= 720 * DotMenuTeamScreen.MAX_HEIGHT_FRACTION + 1.0 \
		and grid.get_combined_minimum_size().y > scroll.size.y + 1.0, "the card area is capped (%.0f) and scrolls" % scroll.size.y)
	host._check(scroll.get_global_rect().end.y <= 720.0, "the window stays on screen")
	for i in 40:
		screen.move(1)
	for i in 4:
		await host.get_tree().process_frame
	var last := grid.get_child(screen.focus) as Control
	var view := scroll.get_global_rect()
	host._check(screen.focus == 40 and view.encloses(last.get_global_rect()), "focus reaches Spectate and scrolls it into view")
	vp.queue_free()
