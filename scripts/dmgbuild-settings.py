"""Finder layout for the Peekaboo terminal-qualification disk image.

The terminal artifact builder supplies absolute artifact paths through dmgbuild's ``-D``
arguments. dmgbuild writes the volume and .DS_Store metadata directly, so
creating a qualification image does not need a GUI session or an automation permission
prompt. Finder metadata must not be attached to the signed app bundle.
"""

app_name = defines["app_name"]
app_path = defines["app_path"]

files = [(app_path, f"{app_name}.app")]
symlinks = {"Applications": "/Applications"}

icon = defines["volume_icon"]
background = defines["background"]

window_rect = ((200, 120), (720, 460))
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

default_view = "icon-view"
show_icon_preview = False
include_icon_view_settings = True
include_list_view_settings = False
arrange_by = None
text_size = 13
icon_size = 128
label_pos = "bottom"
icon_locations = {
    f"{app_name}.app": (180, 230),
    "Applications": (540, 230),
}
format = "UDZO"
filesystem = "HFS+"
