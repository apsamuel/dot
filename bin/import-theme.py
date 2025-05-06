#!/usr/bin/env python
# -*- coding: utf-8 -*-
import asyncio
from calendar import c
import iterm2
# /usr/libexec/PlistBuddy -c 'Add "Custom Color Presets:Synthwave" dict' -c 'Merge "/Users/aaronsamuel/Library/Mobile Documents/com~apple~CloudDocs/dot/terminal/themes/iTerm2-Color-Schemes/schemes/synthwave.itermcolors" "Custom Color Presets:Synthwave"' "$HOME/Library/Preferences/com.googlecode.iterm2.plist"

# async def get_app():
#     connection = iterm2.Connection()
#     app = await iterm2.async_get_app(connection)
#     if app is None:
#         print("No iTerm2 app found.")
#         return None
#     return app


# async def import_theme(app, theme_path):
#     # Load the theme file
#     with open(theme_path, 'r') as f:
#         theme_data = f.read()

#     # Parse the theme data
#     theme_dict = iterm2.parse_theme_data(theme_data)

#     # Import the theme into iTerm2
#     await app.async_import_theme(theme_dict)
