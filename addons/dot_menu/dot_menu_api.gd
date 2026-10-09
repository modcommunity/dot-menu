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
const LEVEL := 1
const OLDEST := 1
