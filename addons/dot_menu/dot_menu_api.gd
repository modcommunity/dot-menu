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
const LEVEL := 2
const OLDEST := 1
