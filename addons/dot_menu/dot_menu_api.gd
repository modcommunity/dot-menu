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
#    DotMenuSettings.leave_on_its_own and _fill_help().
const LEVEL := 4
const OLDEST := 1
