extends RefCounted

## dot-menu's API level. The rule for bumping it is on [DotAddonApi].
##
## LEVEL rises by one for anything a game could call that did not exist before. OLDEST is
## raised to LEVEL when something a game could have called is removed or changes meaning,
## because every pack built before that no longer compiles against this addon.

# 1: the first release: DotMenu, DotMenuScreen, DotMenuHelp, DotMenuPicker,
#    DotMenuLayoutEditor, DotMenuScoreboard, DotMenuSettings, DotMenuApplier,
#    DotMenuStock, DotMenuBindings, DotMenuConfig, DotMenuPage, DotMenuSection,
#    DotMenuRow, DotMenuKit, DotMenuPalette, DotMenuThemes.
# 2: DotMenuNetStat (follow, read_settings) and DotMenu.net_stat; DotMenuStock advanced_page(),
#    declare_net_stat() and the net_stat,
#    net_stat_height and net_stat_position settings; DotMenuConfig.net_stat.
# 3: voice: DotMenuStock.GROUP_VOICE (in DEFAULT_GROUPS), VOICE_ROWS, input_device_row(), the
#    voice_mode and voice_input_device settings; DotMenuBindings.add_voice() (bind_voice_talk on
#    the dot_voice_talk action); DotMenuApplier.bind_voice(), VOICE_SERVICE and
#    voice_available_changed; DotMenuSettings.bind_voice(); DotMenu.hide_rows().
# 4: the help key and the stock Leave: DotMenuBindings.HELP_ACTION/HELP_SETTING/HELP_KEY,
#    add_help(), help_group(), defaults_on(); DotMenu.help_action defaults to HELP_ACTION,
#    leave_on_its_own, leave_link, leave_service, leave(), leave_label();
#    DotMenuHelp.about, add_text(), heading(), help_key_shown();
#    DotMenuSettings.leave_on_its_own and _fill_help(); DotMenuConfig.help_hint and
#    DotMenu.help_hint, the HUD's help plate.
# 5: the map menu: DotMenuMaps; DotMenu.use_maps(), open_maps(), maps, maps_action, toast(),
#    toast_text(), open_picker(items, title, close_action, on_chosen); DotMenuBindings
#    MAPS_ACTION/MAPS_SETTING/MAPS_KEY and add_maps(); DotMenuSettings.map_menu and use_maps();
#    picker rows' `detail` and `thumbnail`, DotMenuPicker.thumbnail_texture().
# 6: the loadout menu: DotMenuLoadout, DotMenuLoadoutScreen; DotMenu.use_loadout(), open_loadout(),
#    open_loadout_screen(), loadout, loadout_screen, loadout_action; DotMenuBindings
#    LOADOUT_ACTION/LOADOUT_SETTING/LOADOUT_KEY and add_loadout(); DotMenuSettings.loadout_menu and
#    use_loadout().
# 7: the HUD follows the theme: DotMenu.follow_hud(), unfollow_hud(), followed_huds(),
#    hud_scale(); DotMenuPalette.hud_theme(), NUMBERS and the hud_edge, hud_ink,
#    hud_highlight, hud_keycap, hud_keycap_text, hud_keycap_edge and hud_team_fill fields;
#    the hud_scale stock setting and its row; the Arcade stock theme. Needs dot-ui 6.
const LEVEL := 7
const OLDEST := 1
