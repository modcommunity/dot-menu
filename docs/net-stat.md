# net_stat: the connection, drawn

`DotMenuNetStat` is a corner overlay at four levels (off, numbers, numbers and a graph of arrivals by channel with ping across it, everything: departures, frame time, the server's own frame, a legend). It is driven by three stock settings in `GROUP_INTERFACE` — `net_stat` (an INTEGER, because it is what a person types: every console here binds the schema's keys, so `net_stat 2` and the Advanced page are one value), `net_stat_height`, `net_stat_position` — and applied by `DotMenu` itself, beside `show_fps`, which steps aside while net_stat is up because net_stat shows the frame rate too. The stock **Advanced** page holds the three rows.

**A game with its own settings and no `DotMenu`** (game-arena, game-hungario) uses the same two halves: `DotMenuStock.declare_net_stat(schema)` adds the three settings, and `DotMenuNetStat.follow(host, settings)` puts the overlay on a layer of its own and follows them. `read_settings` is the one place the three are read, for `DotMenu` and `follow` alike. `follow` connects a METHOD to `settings.changed`, never a lambda capturing the overlay: a host that frees its HUD before its settings left the lambda's capture pointing at nothing, and the engine errors on the next change (the suite's first run).

**Where the numbers come from:** `DotMeteredPeer.of(multiplayer.multiplayer_peer)`, from the overlay's own node. dot-server's `DotClientLink` wraps its peer in one, and the shell scopes one MultiplayerAPI over both the link and the game root, so a delivered game's menu reaches its link's meter without naming dot-server. `source` overrides it (the suite and the screenshot feed one by hand).

Three things decided by looking at it rather than by reasoning about it:

- **The scale is the 90th percentile with headroom, not the peak.** A content download is one tall bar, and scaling to it flattened five seconds of ordinary traffic into a strip of stubs on the first render. Taller bars are clipped with a cap in the HUD text colour.
- **Names and scales go in a gutter left of the graphs**, never over the bars: the first render put "out 9.8 KB/s" behind its own bars.
- **Top right by default.** Bottom right (where the classic graphs sit) ran into mg-wipeout's "N across" counter on the first connected render; top right is the frame counter's corner, which net_stat replaces.

**A browser's arrivals are one colour, honestly.** Godot's WebSocket peer reports every packet on channel 0 (dot-core's `dual_transport_selftest` pins it), so over WebSocket the incoming bars cannot be split and the legend says so; departures are split on both, because the channel is known at the send. Jitter is ENet's own round-trip variance where it has one: the heartbeat samples every two seconds and carries the frame it waited for, which read ±36 ms against an 8 ms ping in a slow process.

`tools/screenshot.sh` renders `net_stat_1/2/3`, a tall one in the paper theme over WebSocket, and the Advanced page, over made-up traffic shaped like a client's. dot-server-deploy's `wipeout_client` proves the chain end to end over a real socket (a delivered game's console, its menu, the link's meter).

More that a picture decided:

- **A game may choose its own default corner** (`declare_net_stat(schema, &"top_left")`): game-hungario's top right is its leaderboard and its bottom corners its minimap and mass bar, so it defaults to the top left, where only its message feed comes and goes.
- **The plate is at least 85% opaque.** At 68% a HUD message feed underneath read straight through the graph. Measured on the render: text under the plate peaks at about 90 of 765, beside it at 600.
- **Offline, the panel shrinks to one line of text** (the frame rate and "offline"); at level 3 it had reserved five empty rows. It re-lays itself out when a connection appears or goes.
- `follow` puts its layer at 120: over a HUD and the menu (110), under the console (128).
