#!/usr/local/bin/genv bash
#shellcheck shell=bash

OPERATING_SYSTEM=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCHITECTURE=$(uname -m | tr '[:upper:]' '[:lower:]')

export ARCHITECTURE OPERATING_SYSTEM