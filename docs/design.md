# Design

## The one idea

**A menu row is a view of a setting, never a copy of one.** A row reads `DotSettingsManager` when its page is drawn and writes it when changed; `DotMenuApplier` is the one place a stock setting is APPLIED, at boot and on change alike. So there is no Apply button, a value changed at the console is what the menu shows next, and a page holds no Controls between draws: `DotMenuPage` is data, rebuilt into widgets every time it is shown.

- **A row's range and options come from the `DotSettingsDef`** unless the row narrows them. A slider with a second copy of the range will one day offer a value the setting refuses.
- **A row whose setting the schema does not declare is not drawn.** That lets the stock pages carry every stock row while a game declares only what it applies. The alternative is a switch that does nothing, this family's most repeated bug (g2gfast shipped five).
- **Live rows** (`live_toggle`, `live_select`, `live_slider`) are state somebody else owns: a server's rule, a flashlight the next server may refuse. Stored, they would be a promise the next server is free to break.

## Why not in dot-ui

dot-ui ships no art and names nothing outside dot-core; its `DotSettingsPanel` generates a plain form from a `DotConfig`. This is the opposite end: a designed default with opinions (the g2gfast look Christian asked to keep), built on dot-settings by name. In dot-ui it would make dot-ui depend on dot-settings and impose a look on every consumer. dot-ui keeps its primitives (`DotInputBinding`, `DotScreenStack`, `DotChatWindow`); this depends on dot-ui, dot-settings and dot-core and nothing else.

**dot-audio, dot-fx and dot-player-controller are driven duck-typed** (`DotMenuApplier`): a mixer is anything with `master`/`sfx`/…, an fx target anything with `shake_scale`/`allow_flashes`/`quality`, a look target anything with `mouse_sensitivity`/`invert_look_y`. With no mixer bound the volumes go straight onto the `AudioServer` buses of those names. Naming those addons would make a 2D game with no dot-audio install all of them to get a menu.

## The stock keys are a contract

`DotMenuStock.declare` uses the keys AND scopes the games were already storing under (`master_volume` DEVICE, `sensitivity` ACCOUNT under the shared `tmc_account` namespace, `field_of_view` SERVER_CLAMPED, …). A different key or scope resets every player's choice the day a game moves onto this. A game that needs another default or range says so in `DotMenuConfig.settings`, never by editing the stock declaration.

`DotMenuApplier.APPLIES`, `APPLIED_BY_MENU` and `LEFT_TO_THE_GAME` list who applies each stock key; the suite fails if `DotMenuStock.KEYS` names one none of them covers, if a stock setting has no row, or a row no setting. **Two g2gfast settings are deliberately not stock**: `raw_input` (applied by nothing; the engine has no portable switch) and `music_volume` in the default groups (no game plays music; `GROUP_MUSIC` opts in). `DotMenuStock.declare(..., except)` leaves out stock keys a game has nothing to apply to.

## Themes go into the schema before the settings load

`ui_theme` is an ENUM over theme ids, and dot-settings corrects a stored value that is not an option **when it loads**. A theme added after that (from `themes_file`, or in code) is refused, and a player who chose it is reset at every start. So `DotMenuConfig.apply_to_schema(schema, themes)` writes the catalogue's ids and the configured default into the def, and must run before `settings.setup()`. `DotMenu.setup` WARNs when the def cannot hold a theme it offers. Found by probing the README's own `DOT_MENU_THEME=paper` line.

A theme is a whole palette (`DotMenuPalette`), menus and HUD, never an accent swap. The kit is an instance rebuilt per theme; static vars would mean one palette per process and two menus in one editor session sharing it. A screen is **rebuilt, not recoloured**, on a theme change: every box is set once as an override when built, and walking the tree to find each again is a second copy of the build that drifts.

## The keys table

`DotMenuBindings` is g2gfast's bindings table as an instance. Four things read it (the InputMap, the schema, the Controls page, the help screen) and must never disagree. **Rebinding a taken key SWAPS**: refusing makes a player unbind one thing to bind another, stealing leaves an action on nothing. `rebind` and `reset_all` apply to the InputMap themselves, so both halves of a swap land together.

**`stored()` returns the effective binding, not the stored text.** A document cleared by hand stores `""` for a key really on its default; comparing the text let a default key be bound to a second action with no conflict found. And it is in dot-ui's **current spelling**: a document from before dot-ui named the wheel stores `Mouse 4`, which the Controls page would draw as a thumb button; the round trip through `DotInputBinding` draws `Wheel up` (and changes nothing on an older dot-ui).

## A server may hide and clamp; it may never set or read

`DotMenu.apply_server_rules` takes `rows_hidden`, `pages_hidden`, `themes`, `leave_text` and `clamps`, and `release_server_rules` undoes all of it on leaving. Clamps go through dot-settings' policy (`apply_server_clamps`), a bound the player's own value stays under. The row shows `chosen_value` (what the player picked and gets back) with "This server caps it at 95" under it; showing the clamped value would quietly replace their choice. A theme the server does not offer is moved off for the connection; the stored choice is untouched.

## Voice

`GROUP_VOICE` is in `DEFAULT_GROUPS`, so every game declaring the defaults has `voice_mode` (push to talk or open microphone, ACCOUNT) and `voice_input_device` (DEVICE; the row is native only, because a browser picks the microphone in its own prompt). `DotMenuSettings.setup` adds `DotMenuBindings.add_voice()` (Push to talk, `bind_voice_talk`, the `dot_voice_talk` action dot-voice reads, V) to a game's key table when the schema has the voice group, so the key is in every game's Controls page and help screen under one setting. `voice_volume` stays with the volumes and sets the `Voice` bus.

**The voice is found, not handed to the menu.** A game's chat client publishes its own player's `DotVoiceManager` as `dot_voice_client` (dot-game's `DotGameChatClient` does it for every game on that base); `DotMenuApplier` binds what is registered there at setup and anything registered later through `DotRegistryBus`, whichever is built first. It calls `set_open_mic`, `set_input_device` and `set_volume` duck-typed, so dot-menu names nothing in dot-voice. A bound voice's `server_enabled_changed` becomes `voice_available_changed`, and `DotMenuSettings` hides `DotMenuStock.VOICE_ROWS` with `DotMenu.hide_rows(&"voice", …)` while the server has `sv_voice_enable 0`. `hide_rows` keeps its own list beside a server's `rows_hidden`, so `release_server_rules` on leaving does not show rows hidden for another reason.

## The pointer, Escape and overlays: one list

`DotMenu` owns which overlay is open (menu, help, picker, layout editor, any `add_overlay`), what Escape does, who has the pointer and the theme, for dot-ui's reason: easy alone, where the bugs are together. **While anything is open every key is the menu's** (`handle_event` returns true): R behind a menu is a restart nobody asked for. `busy` is the game's "the chat line has the keyboard".

- In a browser, pointer lock exits on Escape and the key may not be delivered, so a lost lock opens the menu; an Escape within `escape_grace_ms` is swallowed or the menu flashes shut; closing by a click recaptures and by a key cannot, so `click_to_play` fires twelve frames later.
- `manage_pointer = false` for a host that owns the mouse (a 2D game, the demo, the suite, `DotMenuSettings`).
- **`open_on_escape = false`** for a game whose Escape is its own (mg-dangerous-delivery's garage) or which keeps a two-step Escape (game-playground: release the pointer, then open). Escape still closes the menu.

## Help on H and Leave, in every game

**Every game has help on H and the same Escape menu, with Help & commands and Leave, unless it says otherwise** (API 4, from Christian's first play test: nine of thirteen games had no help key and four had no Leave). Both used to be opt-in: `DotMenu.help_action` was empty, and `DotMenuSettings` games turned `show_help` and `show_leave` off because Leave had nothing to do.

- **The help key is a table row like any other key**: `DotMenuBindings.add_help()` (`dot_menu_help`, stored as `bind_help`, H) on the interface or general card. `DotMenuSettings.setup` adds it to every game's table, on the next free key (`free_key(["H", "F1"])`) if the game ships something on H, and gives a game with no table a table holding it. A game whose own help row already uses `bind_help` keeps it, and the menu opens on that action. A `DotMenu` built by hand with no row still gets H: `setup` puts the action on the InputMap and the help screen lists it. **A row on H for anything else is a conflict each game's suite fails on** (`defaults_on("H")`).
- **The HUD says so.** A small "H  Help" plate (`DotMenu.help_hint`, the key as bound now) sits in the corner `DotMenuConfig.help_hint` names (top right, under the frame counter, by default) while nothing is open. A plate, not bare text, because it is read over whatever the map is. A game whose HUD already lists its keys turns it off and puts H in its own list.
- **The help screen is what the game is, then its keys.** `DotMenuHelp.about` is the goal, the first card on the right, headed "How to play"; `add_text` adds prose cards (modes, rules); the title is "How to play <brand>". The keys still come from the table, so a rebinding shows. A `DotMenuSettings` game writes these in `_fill_help(help)`.
- **Leave is stock when `leave_on_its_own`** (on in `DotMenuSettings`): connected, it calls the client link's `disconnect_from_server`, and whatever loaded the game (the client shell) takes the player back to its menu on the disconnect; solo on a desktop it quits. The link is looked up as `dot_client_link` in `DotRegistry` when pressed (duck-typed, so dot-menu names nothing in dot-server), so a link made after the menu is still the one left. The button reads "Leave server", "Quit game", or is hidden solo in a browser (a page cannot close its tab, and a quit there is a frozen canvas). A server's `leave_text` still wins. A game that leaves its own way keeps `leave_on_its_own` off and handles `action_requested(&"leave")`.

## The map menu on M, in every game

**M opens a picker of the game's maps, and choosing one changes to it** (API 5, from Christian's first play test: games booted solo had no way to change the map, and the two that had one said different things). Courses, layouts, routes, houses and modes are all "maps" here; the row says which with its `mode` line.

- **The key is a table row** like help: `DotMenuBindings.add_maps()` (`dot_menu_maps`, stored as `bind_maps`, M), added to every `DotMenuSettings` game's table (`map_menu`, on by default) and by hand to the others. Nothing else in a game's table may default to M; a game that ships something there moves it, and its suite asserts `defaults_on("M")`. A `DotMenu` with no row puts the action on M itself in `use_maps` and lists it on the help screen.
- **The game hands over a list and a change, and that is all**: `menu.use_maps(rows_fn, change_fn)`. A row is `{id, name, mode, detail, thumbnail, current, tags}`; `thumbnail` is a texture or a `res://` path, drawn only if it resolves (never `load()` a missing path), and a page where some maps have pictures keeps an empty frame for the rest so the rows line up. `rows_fn` is read every time M is pressed, so a map pack delivered later is in the next list.
- **Solo the choice is the change**: `change_fn(id)`, and a refusal (`DotResult` failed) is shown with `DotMenu.toast`.
- **Connected, the server decides.** `DotMenuMaps` sends `/mapmenu` through the client link's chat (a prefixed line is a command and is never shown to anyone) and opens on the `map_menu` notice the server answers with: `{maps, allowed, flag, vote, where}`. Allowed, choosing sends `/mapmenu <id>` and the server changes the map through the game's own change path, so every peer follows. Without the flag the owner named (`sv_map_menu_flag`, `generic` by default, which is every staff group from moderator up) the heading is "Vote for a map" and choosing nominates and rocks the vote; with voting off too, the refusal is a toast and nothing opens. The result comes back as a `map_menu` notice with `{result: {ok, text}}`. The server half is dot-vote's `DotVoteMapMenu`, installed with its commands, so every game with a vote has it.
- **The link is found, not handed over**: `dot_client_link` in `DotRegistry` when M is pressed, as for Leave. Nothing here names dot-server or dot-vote; a notice is read by its `topic` and `data`.
- **One picker, two owners.** The map menu opens the same `DotMenuPicker` a game's own list uses (a taunt list), so `open_picker` takes the key that closes this list and who gets its choice: a map id must never reach the game's `picked` handler.

## The loadout menu on B

**B opens a loadout screen: the slots down the left, each slot's choices as cards with a picture, and the highlighted card's statistics against what is equipped** (API 6, from Christian's first play test: "users should be able to choose their loadout using B by default ... make sure the loadout menu is really nice and supports a primary, secondary, melee, and grenades"). Rendered in `screenshots/loadout*.png`.

- **The key is a table row**: `DotMenuBindings.add_loadout()` (`dot_menu_loadout`, stored as `bind_loadout`, B), added by `DotMenuSettings` when the game sets `loadout_menu` (off by default: most of the family's games hand out their kit). It goes in before the talk key, whose fallbacks include B. A `DotMenu` with no row puts the action on B in `use_loadout` and lists it on the help screen.
- **The offer is the server's, the pictures are the client's.** `use_loadout(offer_fn, choose_fn, decorate_fn)`. The offer is dot-loadout's `DotLoadoutManager.offer_for` shape (`{choose, budget, note, slots: [{id, name, fixed, current, choices: [{id, name, cost, tags}]}]}`), which names only ids and numbers because a dedicated server may have no content; `decorate_fn(slot_id, choice)` adds `icon`, `detail`, `kind` and `stats` (`[{label, value 0..1, text}]`). Solo, `offer_fn` and `choose_fn` are the game's own manager; connected, B sends `/loadout` through the client link's chat and opens on the `loadout_menu` notice, and a choice is `/loadout slot=item ...` (dot-loadout's `DotLoadoutCommand`, which publishes through the trust boundary).
- **It shows only what the server will take**: a slot's choices are what this player may put there under the owner's rules, a fixed slot shows its item locked and marked SERVER, and a card that would go over the points budget is dimmed and says by how much. A screen that lets a player pick what is then refused is a screen that lies.
- **A draft, sent once, on close.** A pick changes the draft (a dot on the slot's tab marks it); B, Escape or Done send the changed slots once; Backspace undoes. A publish per click is a store write per click against a rate limit, and an Apply button is one more thing to forget before the round starts. What the game or server did comes back as a toast ("Loadout equipped." in warmup, "you get it when you next spawn" otherwise).
- **Every input**: mouse (hover to look, click to pick), keyboard (arrows, Enter, 1-9, Q/E or Tab for the slot, Backspace), controller through the `ui_*` actions plus the shoulders and Y. Read in the screen's `_input`, ahead of the game.
- **Remembered per account, on the client** (`remember_as(game, account)`, `user://dot_menu/loadouts.json`): a server keys loadouts by session and forgets them on a restart, and the choice is the player's. `restore()` re-sends it on the next join, quietly unless refused.
- **Drawn at a design size (1160x660) and scaled down whole**, as the HUD is, so the cards stay readable at 854x480. The icon frame is a dark case in every theme, because weapon art is usually light on transparent.

## `DotMenuSettings`

Each `mg-*` game carried a ~250-line `<Prefix>Settings` that was the same node renamed: a manager, a `match` pushing four keys at a sampler, a camera and a mixer, and a bare settings screen. `DotMenuSettings` is that node (manager + `DotMenuApplier` + `DotMenu`) with the API those clients already called: `setup(store, with_menu)`, `bind_look/camera/audio/fx`, `open/close/is_open`, `describe()` with `look_bound`/`camera_bound`, and `menu_state_changed`. A game subclasses it for its schema and keeps its call sites. `manage_pointer` is off there because those clients own the pointer and capture on `menu_state_changed`.

## The scoreboard: the server's numbers, held

`DotMenuScoreboard` draws one dictionary in dot-server's `scoreboard_snapshot` shape (`server`, `you`, `players`, `teams`, `header`), whoever produced it: the server's roster through `feed_from(link)`, or a game's own through `source`. **The server half exists because ping and time connected are numbers only the server has for everybody.** dot-server sends the roster only while a client holds its board (`scoreboard.want`), unreliably, twice a second ([dot-server's game-facing.md](../../dot-server/docs/game-facing.md#the-scoreboard-roster)). dot-menu names nothing in dot-server: the feed is duck-typed (`want_scoreboard(open)`, `scoreboard_received`, `scoreboard`).

- **Held, not opened**: it is not one of `DotMenu`'s overlays. It never frees the pointer, never counts toward `any_open()` (so no sampler is suspended), takes no input, and closes on the key's RELEASE wherever that arrives; a board left up because the release came while the chat line had the keyboard could not be dismissed. Escape while it is held opens the menu and drops the board.
- **Customising runs from data to code**: `columns` (kinds text/number/ping/duration/avatar/custom), `decorate(row)`, `prepare(snapshot)`, `group_by`/`sort_by`/`sort_with`, then `build_header`/`build_team_header`/`build_row` replace the pieces outright. `ROW_PAD` pads rows and their titles alike so they stay aligned.
- **`prepare(snapshot)` works on a copy**: a game whose clients already replicate their own numbers (wipeout's points, deathrun's sides) merges them into the server's roster on the client instead of sending them again. Where only the server knows a number (g2gfast's best times, delivery's bank, look-at-me's levels), the game's module adds it through dot-server's `scoreboard_fields`, which dot-game wraps as `_game_board_fields(session)`.
- A game that keeps its own Tab handling opens and closes `menu.scoreboard` itself; one with a key table sets `scoreboard_action` and the menu holds it.
