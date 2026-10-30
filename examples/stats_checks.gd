extends RefCounted

## DotMenuStats columns and DotMenuStatsPanel, run from menu_selftest.

const SNAP := {
	"server": {"name": "S"}, "you": 2,
	"stat_columns": [
		{"key": "kills", "title": "Kills", "column": "default"},
		{"key": "acc", "title": "Accuracy", "column": "optional"},
		{"key": "secret", "title": "Secret", "column": "hidden"},
	],
	"players": [
		{"id": 1, "name": "Ann", "score": 5, "st_kills": "2", "lt_kills": "102", "st_acc": "40%", "lt_acc": "38%"},
		{"id": 2, "name": "Bo", "score": 9, "st_kills": "7", "lt_kills": "57", "st_acc": "50%", "lt_acc": "45%"},
	],
}


static func run(host: Node) -> void:
	host._section("Stats: lifetime columns on the board and a card for your own figures")
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.disable_3d = true
	host.add_child(vp)
	var board := DotMenuScoreboard.new()
	vp.add_child(board)
	var stats := DotMenuStats.install(board)
	host._check(DotMenuStats.install(board) == stats, "installing twice gives the same node")
	board.source = func() -> Dictionary: return SNAP
	board.open()
	for i in 4:
		await host.get_tree().process_frame
	var keys: Array = board.columns.map(func(c: Dictionary) -> Variant: return c.get("key"))
	host._check(&"lt_kills" in keys and &"lt_acc" in keys and not (&"lt_secret" in keys), "a column per listed stat, none for a hidden one " + str(keys))
	var shown: Array = board.visible_columns().map(func(c: Dictionary) -> Variant: return c.get("key"))
	host._check(&"lt_kills" in shown and not (&"lt_acc" in shown), "the default one is shown, the optional one waits " + str(shown))
	stats.enabled = false
	host._check(not (&"lt_kills" in board.columns.map(func(c: Dictionary) -> Variant: return c.get("key"))), "cl_stats_ui off removes them")
	stats.enabled = true
	host._check(&"lt_kills" in board.columns.map(func(c: Dictionary) -> Variant: return c.get("key")), "and on brings them back")

	var panel := DotMenuStatsPanel.new()
	vp.add_child(panel)
	panel.show_snapshot(SNAP)
	panel.show_for(0.0)
	await host.get_tree().process_frame
	host._check(panel.visible and panel.my_row().get("name") == "Bo", "the card opens on your own row")
	var table := panel.find_child("Table", true, false) as GridContainer
	host._check(table != null and table.get_child_count() == 3 * 3, "a header and one line per shown stat, three cells each")
	panel.enabled = false
	host._check(not panel.visible, "disabled, it closes")
	panel.show_for(1.0)
	host._check(not panel.visible, "and will not open")
	vp.queue_free()
