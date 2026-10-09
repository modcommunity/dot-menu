class_name DotMenuPage
extends RefCounted

## One page of the menu: a tab in the sidebar, a title, a sentence, and cards of rows.
##
## [codeblock]
## var page := DotMenuPage.make(&"gameplay", "Gameplay", "Your style and your view.")
## page.section("View").add(DotMenuRow.toggle(&"show_own_body", "Your own body"))
## menu.add_page(page, &"video")        # before Video
## [/codeblock]
##
## [b]Data, drawn fresh every time it is shown.[/b] A page holds no Controls: the screen
## builds them from this when the page opens and throws them away when it closes, so a row
## whose words depend on a server ("This server has turned flashlights off") is right every
## time, and a page added or changed while the menu is shut costs nothing.
##
## A page a game wants to draw entirely itself sets [member build] — `func(kit, body)` adds
## whatever it likes to the scrolling column — and keeps the sidebar, the title and the
## theme.

var id: StringName = &""
var title: String = ""

## The sentence under the title.
var blurb: String = ""

var sections: Array[DotMenuSection] = []

## `func(kit: DotMenuKit, body: VBoxContainer) -> void`, drawn after [member sections].
var build: Callable = Callable()

## `func() -> bool`. False leaves the page out of the sidebar.
var visible_if: Callable = Callable()

## Draw a card per [DotMenuBindings] group after [member sections], each row a key button,
## and a button that puts every key back. The stock Controls page sets it; a game that
## wants its keys on a page of their own sets it there instead.
var show_bindings: bool = false


static func make(p_id: StringName, p_title: String, p_blurb: String = "") -> DotMenuPage:
	var p := DotMenuPage.new()
	p.id = p_id
	p.title = p_title
	p.blurb = p_blurb
	return p


## The section called [param title] (or [param p_id]), made at the end if there is none —
## so adding a row to "Display" works whether or not a stock page already had one.
func section(p_title: String, p_id: StringName = &"") -> DotMenuSection:
	var want := p_id if p_id != &"" else StringName(p_title.to_snake_case())
	for s in sections:
		if s.id == want:
			return s
	var made := DotMenuSection.make(p_title, want)
	sections.append(made)
	return made


func find_section(p_id: StringName) -> DotMenuSection:
	for s in sections:
		if s.id == p_id:
			return s
	return null


## Puts a section before the one called [param before], or at the end when there is none.
func insert_section(s: DotMenuSection, before: StringName = &"") -> DotMenuSection:
	for i in range(sections.size()):
		if sections[i].id == before:
			sections.insert(i, s)
			return s
	sections.append(s)
	return s


func remove_section(p_id: StringName) -> bool:
	for i in range(sections.size()):
		if sections[i].id == p_id:
			sections.remove_at(i)
			return true
	return false


func find_row(row_id: StringName) -> DotMenuRow:
	for s in sections:
		var r := s.find_row(row_id)
		if r != null:
			return r
	return null


## Takes the row out of whichever section has it. Returns it, for moving elsewhere.
func take_row(row_id: StringName) -> DotMenuRow:
	for s in sections:
		var r := s.find_row(row_id)
		if r != null:
			var _gone := s.remove_row(row_id)
			return r
	return null


func is_shown() -> bool:
	return not visible_if.is_valid() or bool(visible_if.call())


func describe() -> Dictionary:
	var rows := 0
	for s in sections:
		rows += s.rows.size()
	return {"id": String(id), "title": title, "sections": sections.size(), "rows": rows}
