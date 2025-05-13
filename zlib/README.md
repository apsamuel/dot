# ZLIB

This directory contains files which are sourced when opening a new ZSH

## File Names

> example: `000-a-example.sh`
>
> 2 levels of prefixing control the load order

`*.sh` files in this directory are sourced when a new shell session is started

1. *`\d{3}`* - a three digit numeral with left-padding
2. *`[a-z]`* - a single lowercase alphabetical character
3. *`[a-z]*`* - the module name
