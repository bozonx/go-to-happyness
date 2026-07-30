class_name DecorCatalogPanel
extends EditorCatalogPanel

## Catalog sub-panel of decor mode: one-level-at-a-time browse navigation,
## search, tag filters, recent assets, and snap-step selection.
##
## Delegates core catalog browsing and UI management to EditorCatalogPanel.

const SCOPE := WorldAssetDef.SCOPE_BUILDING


func setup(controller: Object, editor: Node = null, p_scope: StringName = WorldAssetDef.SCOPE_BUILDING) -> void:
	super.setup(controller, editor, p_scope)
