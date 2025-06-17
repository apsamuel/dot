global AllArtists

set AllArtists to {} -- a unique list of artists
tell application "Music"
  tell library playlist 1
    repeat with aTrack in (get every track)
      set thisArtist to artist of aTrack
      if thisArtist is not in AllArtists then
        -- log thisArtist
        -- add the artist name to the list, don't add duplicates
        set AllArtists to AllArtists & {thisArtist}
      end if
    end repeat
  end tell
end tell