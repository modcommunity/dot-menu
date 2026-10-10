# dot-menu

In-game menus as data, extracted from game-g2gfast (2026-10-09). Read `../../CLAUDE.md` first for the family-wide rules, and dot-ui's and dot-settings' own `CLAUDE.md`, because this sits on both and keeps their rules.

## The one idea

**A menu row is a view of a setting, never a copy of one.** A row reads `DotSettingsManager` when its page is drawn and writes it when changed; `DotMenuApplier` is the one place a stock setting is APPLIED, at boot and on change alike. So there is no Apply button, a value changed at the console is what the menu shows next, and a page holds no Controls between draws: `DotMenuPage` is data, rebuilt into widgets every time it is shown.

Everything else follows from that:

- **A row's range and options come from the `DotSettingsDef`** unless the row narrows them. A slider with a second copy of the range is a slider that will one day offer a value the setting refuses.
- **A row whose setting the schema does not declare is not drawn.** That is what lets the stock pages carry every stock row while a game declares only what it applies — the alternative is a switch that does nothing, which is this family's most repeated bug (g2gfast shipped five).
- **Live rows** (`live_toggle`, `live_select`, `live_slider`) are state somebody else owns — a server's rule, a flashlight the next server may refuse. Stored, they would be a promise the next server is free to break.

## Where things live, and why not in dot-ui

dot-ui ships no art and names nothing outside dot-core; its `DotSettingsPanel` generates a plain form from a `DotConfig`. This is the opposite end: a designed default with opinions (the g2gfast look the user asked to keep), built on dot-settings by name. Putting it in dot-ui would make dot-ui depend on dot-settings and impose a look on every consumer. So: dot-ui keeps the primitives it already had (`DotInputBinding`, `DotScreenStack`, `DotChatWindow`), and this depends on dot-ui, dot-settings and dot-core and nothing else (net_stat reads dot-core's `DotMeteredPeer`; dot-server is never named).

**dot-audio, dot-fx and dot-player-controller are driven duck-typed** (`DotMenuApplier`): a mixer is anything with `master`/`sfx`/…, an fx target anything with `shake_scale`/`allow_flashes`/`quality`, a look target anything with `mouse_sensitivity`/`invert_look_y`. With no mixer bound the volumes go straight onto the `AudioServer` buses of those names. Naming those three addons would make a 2D game with no dot-audio install all of them to get a menu.

## The stock keys are a contract

`DotMenuStock.declare` uses the keys AND scopes six games were already storing under (`master_volume` DEVICE, `sensitivity` ACCOUNT under the shared `tmc_account` namespace, `field_of_view` SERVER_CLAMPED, …). A different key or scope resets every player's choice the day a game moves onto this. A game that needs another default or range says so in `DotMenuConfig.settings`, never by editing the stock declaration.

`DotMenuApplier.APPLIES`, `APPLIED_BY_MENU` and `LEFT_TO_THE_GAME` list who applies each stock key, and the suite fails if `DotMenuStock.KEYS` names one that none of them covers, or if a stock setting has no row, or a row no setting. **Two settings g2gfast had are deliberately not stock:** `raw_input` (declared there, applied by nothing, and the engine has no portable switch for it) and `music_volume` in the default groups (no game here plays music; a slider for a silent bus is a control that does nothing — `GROUP_MUSIC` opts in).

## Themes go into the schema before the settings load

`ui_theme` is an ENUM over theme ids, and dot-settings corrects a stored value that is not an option **when it loads**. A theme added after that — from `themes_file`, or in code — is a value the setting refuses, and a player who chose it is put back on the default at every start. So `DotMenuConfig.apply_to_schema(schema, themes)` writes the catalogue's ids and the configured default into the def, and must run before `settings.setup()`. `DotMenu.setup` WARNs when the def cannot hold a theme it offers. Found by probing the README's own `DOT_MENU_THEME=paper` line: the configured theme was ignored for a new player.

A theme is a whole palette (`DotMenuPalette`), menus and HUD, never an accent swap. The kit is an instance rebuilt per theme — g2gfast kept static vars, which is one palette per PROCESS and two menus in one editor session sharing it. A screen is **rebuilt, not recoloured**, on a theme change: every box is set once as an override when built, and walking the tree to find each again is a second copy of the build that drifts from the first.

## The keys table

`DotMenuBindings` is g2gfast's `G2GBindings` as an instance. Four things read it (the InputMap, the schema, the Controls page, the help screen) and must never disagree. Rebinding a taken key SWAPS — refusing makes a player unbind one thing to bind another, stealing leaves an action on nothing. `rebind` and `reset_all` apply to the InputMap themselves, so the two halves of a swap land together whoever is listening.

**`stored()` returns the effective binding, not the stored text.** A document cleared by hand stores `""` for a key that is really on its default (`apply_row` falls back); comparing the text, binding that default key to something else found no conflict and left one key on two actions. g2gfast has the same hole; the suite checks it here.

## A server may hide and clamp; it may never set or read

`DotMenu.apply_server_rules` takes `rows_hidden`, `pages_hidden`, `themes`, `leave_text` and `clamps`, and `release_server_rules` undoes all of it on leaving. Clamps go through dot-settings' policy (`apply_server_clamps`), which is a bound the player's own value stays under. The row shows `chosen_value` — what the player picked, and gets back — with "This server caps it at 95" under it; showing the clamped value would quietly replace their choice. A theme the server does not offer is moved off for the connection; the stored choice is untouched.

## The pointer, Escape, and overlays — one list

`DotMenu` owns which overlay is open (menu, help, picker, layout editor, and any `add_overlay`), what Escape does, who has the pointer and the theme, for dot-ui's reason: easy alone, where the bugs are together. While anything is open **every key is the menu's** (`handle_event` returns true): R behind a menu is a restart nobody asked for. `busy` is the game's "the chat line has the keyboard".

The browser half is g2gfast's, unchanged: a browser exits pointer lock on Escape and may not deliver the key, so a lost lock opens the menu; an Escape within `escape_grace_ms` is swallowed or the menu flashes shut; closing by a click recaptures and closing by a key cannot, so `click_to_play` fires twelve frames later.

`manage_pointer = false` for a host that owns the mouse (a 2D game, the demo, the suite).

## `DotMenuSettings`: the node six minigames had written by hand

Each `mg-*` game carried a ~250-line `<Prefix>Settings` that was the same node renamed: a manager, a `match` pushing four keys at a sampler, a camera and a mixer, and a bare `DotSettingsScreen` on a stack. `DotMenuSettings` is that node (manager + `DotMenuApplier` + `DotMenu`) with the API those clients already call — `setup(store, with_menu)`, `bind_look/camera/audio/fx`, `open/close/is_open`, `describe()` with `look_bound`/`camera_bound`, and `menu_state_changed` — so a game subclasses it for its schema and keeps its call sites. `manage_pointer` is off there because those clients own the pointer and capture on `menu_state_changed`.

`DotMenuStock.declare(..., except)` is how such a game leaves out stock keys it has nothing to apply to (no UI bus, no fx): a declared setting nothing applies is a switch that does nothing.

## The scoreboard: the server's numbers, held

`DotMenuScoreboard` draws one dictionary — dot-server's `scoreboard_snapshot` shape (`server`, `you`, `players`, `teams`, `header`) — whoever produced it: the server's roster through `feed_from(link)`, or a game's own through `source`. **The server half exists because ping and time connected are numbers only the server has for everybody**; a client knows its own ping and when it joined, nobody else's, so a board built client-side had to replicate both per game and most did not. dot-server sends the roster only while a client holds its board (`scoreboard.want`), unreliably, twice a second; `scoreboard_fields` and `scoreboard_extra` are the game's columns and teams. dot-menu names nothing in dot-server: the feed is duck-typed (`want_scoreboard(open)`, `scoreboard_received`, `scoreboard`).

**Held, not opened**: it is not one of `DotMenu`'s overlays. It never frees the pointer, never counts toward `any_open()` (so no sampler is suspended), takes no input, and closes on the key's RELEASE wherever that arrives — a board left up because the release came while the chat line had the keyboard is one the player cannot get rid of. Escape while it is held opens the menu and drops the board.

Customising runs from data to code: `columns` (kinds text/number/ping/duration/avatar/custom), `decorate(row)`, `prepare(snapshot)` (on a copy: client-side teams and header over the server's roster), `group_by`/`sort_by`/`sort_with`, then `build_header`/`build_team_header`/`build_row` replace the pieces outright. The first render had a highlighted row's ping touching its outline; `ROW_PAD` pads rows and their column titles alike so they stay aligned.

## Who uses it, and the two switches the games needed (2026-10-09)

Every game but game-arena is on it: game-g2gfast (the menu it came from, its pages in `g2g_menu_pages.gd`), the six `mg-*` games (`DotMenuSettings` subclasses), game-playground (the Escape menu; its spawn menu and server browser stay on its own screen stack), game-hungario (the Tab board only: its settings are a `DotConfig`, which a view of dot-settings cannot show without changing how it stores them) and dot-game-template. Two switches came out of fitting them:

- **`DotMenu.open_on_escape`**: off for a game whose Escape is its own (mg-dangerous-delivery's garage) or which keeps a two-step Escape (game-playground: release the pointer, then open). Escape still closes the menu.
- **`DotMenuScoreboard.prepare(snapshot)`**: a game whose clients already replicate their own numbers (wipeout's points, deathrun's sides) merges them into the server's roster on the client, on a copy, instead of sending them again. Where only the server knows a number (g2gfast's best times, delivery's bank, look-at-me's levels kept per account), the game's module adds it through dot-server's `scoreboard_fields`, which dot-game wraps as `_game_board_fields(session)`.

A game that keeps its own Tab handling (most `mg-*`, playground) opens and closes `menu.scoreboard` itself; one with a key table sets `scoreboard_action` and the menu holds it.

## net_stat

- `DotMenuNetStat` is the connection overlay; `DotMenu` drives it from the `net_stat`, `net_stat_height` and `net_stat_position` settings (an INTEGER level, because every console here binds settings by name). A game with no menu uses `DotMenuStock.declare_net_stat(schema, corner)` and `DotMenuNetStat.follow(host, settings)`.
- It reads `DotMeteredPeer.of(multiplayer.multiplayer_peer)` and never names dot-server.
- `follow` connects a method, never a lambda capturing the overlay: a freed overlay left a dangling capture that errors on the next change.
- Over WebSocket all arrivals are channel 0, so they are drawn in one colour and the legend says so.
- Read [docs/net-stat.md](docs/net-stat.md) before changing how it scales, where it sits or what it draws.

## Delivered games and the client shell

A game delivered as a pack cannot use its OWN `class_name`s (see the `godot-pack-class-name-limit` memory), but it can use an addon's, because the addon is compiled into the client shell. So a pack that uses `DotMenu*` needs **a shell built with dot-menu in it**: dot-server-deploy must link `addons/dot_menu` and the shell must be rebuilt and published before a game pack that depends on it. A pack running in an older shell fails to parse every script that names `DotMenu`. That is the same "untagged addon" trap as every other addon — tag dot-menu, rebuild the shell, then publish games.

## Validating

```bash
godot --headless --path . --import
godot --headless --path . res://examples/menu_selftest.tscn   # 15 sections, 197 checks
tools/screenshot.sh                                            # every page, theme and screen
```

`tools/screenshot.sh` is not optional after a visual change: a menu is the thing no assertion can judge, and its first run found an engine error per unnamed row (a control named with an empty string) that the suite never drew. A scene that fails to parse HANGS the render rather than failing it; parse-check `examples/menu_demo.gd` first. Look at `screenshots/theme_paper.png` after touching the kit — the light theme is where a hard-coded colour shows.
