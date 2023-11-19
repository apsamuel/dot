#!/usr/local/bin/bash

OPERATING_SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCHITECTURE=$(uname -m | tr '[:upper:]' '[:lower:]')

export ARCHITECTURE OPERATING_SYSTEM