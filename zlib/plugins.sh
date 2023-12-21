# shellcheck shell=bash
DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")

if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi

export ZSH_OPTIONS=(
    autopushd            # Push the old directory onto the directory stack when changing directories.
    extendedglob         # Use extended globbing syntax.
    share_history        # Share history between all sessions.
    hist_ignore_all_dups # Delete old recorded entry if new entry is a duplicate.
    BANG_HIST            # Treat the '!' character specially during expansion.
    EXTENDED_HISTORY     # Write the history file in the ":start:elapsed;command" format.
    INC_APPEND_HISTORY   # Write to the history file immediately, not when the shell exits.
    SHARE_HISTORY        # Share history between all sessions.
    histexpiredupsfirst  # Expire duplicate entries first when trimming history.
    histignoredups       # Don't record an entry that was just recorded again.
    histignorealldups    # Delete old recorded entry if new entry is a duplicate.
    HIST_FIND_NO_DUPS    # Do not display a line previously found.
    HIST_IGNORE_SPACE    # Don't record an entry starting with a space.
    histsavenodups       # Don't write duplicate entries in the history file.
    HIST_REDUCE_BLANKS   # Remove superfluous blanks before recording entry.
    histverify           # Don't execute immediately upon history expansion.
    HIST_BEEP            # Beep when accessing nonexistent history.
)