class_name DotMenuCfg
extends RefCounted

## Reads `admin_menu.yml` from `cfg/addons/dot_menu/`, the operator's `cfg/server/addons/dot_menu/` over it.
## A flat `legacy_dir/admin_menu.yml` is still read (one WARN) while no new copy exists, until [constant DotCfgLegacy.REMOVE_AFTER].

const CFG_ADDON := "dot-menu"
const ADMIN_MENU_FILE := "admin_menu.yml"


## Value: the merged tree. Maps merge key by key, a list or scalar is replaced whole.
static func load_admin_menu(legacy_dir: String = "res://cfg") -> DotResult:
	var tree := {}
	var res := DotAddonConfig.apply_file(
		CFG_ADDON, ADMIN_MENU_FILE, legacy_dir,
		func(values: Dictionary, path: String) -> PackedStringArray:
			DotAddonConfig.merge(tree, values)
			return PackedStringArray([path])
	)
	if not res.ok:
		return res
	return DotResult.success(tree)
