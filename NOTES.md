# CLI

FZF viewer for git diff

```sh
git diff --name-only |
fzf --ansi --preview "git diff --color=always -- {-1}" \
--preview-window=up:30%:wrap \
--bind "enter:execute(git diff --color=always -- {-1})" \
--bind "ctrl-d:toggle-preview" \
--bind "ctrl-a:select-all" \
--bind "ctrl-x:select-all+accept" \
--bind "ctrl-t:toggle-preview-wrap"
```

Merge a value in the Plist file for iterm2

```sh
/usr/libexec/PlistBuddy \
-c 'Add "Custom Color Presets:Synthwave" dict' \
-c 'Merge "/Users/aaronsamuel/Library/Mobile Documents/com~apple~CloudDocs/dot/terminal/themes/iTerm2-Color-Schemes/schemes/synthwave.itermcolors" \
"Custom Color Presets:Synthwave"' "$HOME/Library/Preferences/com.googlecode.iterm2.plist"
```
