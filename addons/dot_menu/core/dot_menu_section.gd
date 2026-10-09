class_name DotMenuSection
extends RefCounted

## A titled card of rows on a page: "Display", "Volume", "Movement".
##
## A section with nothing drawable in it is not drawn — no bare heading over an empty card
## when every row in it names a setting this game did not declare. dot-ui's settings panel
## learned that one first ("Group headings are added lazily").

## What [method DotMenuPage.section] finds it by. Defaults to the title, lowercased.
var id: StringName = &""

var title: String = ""

var rows: Array[DotMenuRow] = []

## BINDINGS: draw every row of this group of the menu's [DotMenuBindings] after [member rows].
## Empty draws none. What lets the Controls page grow a card per group without naming one.
var binding_group: String = ""


static func make(p_title: String, p_id: StringName = &"") -> DotMenuSection:
	var s := DotMenuSection.new()
	s.title = p_title
	s.id = p_id if p_id != &"" else StringName(p_title.to_snake_case())
	return s


func add(row: DotMenuRow) -> DotMenuSection:
	if row != null:
		rows.append(row)
	return self


## Puts [param row] before the row called [param before], or at the end when there is none.
func insert_before(before: StringName, row: DotMenuRow) -> DotMenuSection:
	for i in range(rows.size()):
		if rows[i].row_id() == before:
			rows.insert(i, row)
			return self
	rows.append(row)
	return self


func find_row(row_id: StringName) -> DotMenuRow:
	for r in rows:
		if r.row_id() == row_id:
			return r
	return null


func remove_row(row_id: StringName) -> bool:
	for i in range(rows.size()):
		if rows[i].row_id() == row_id:
			rows.remove_at(i)
			return true
	return false
