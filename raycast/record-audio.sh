#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Record Audio Meeting
# @raycast.mode silent
# @raycast.icon 🎙️
# @raycast.packageName Memoant

# Documentation:
# @raycast.description Start recording audio-only meeting with automatic transcription
# @raycast.author Kyle Northup

cd ~/Code/memoant && uv run memoant record --mode meeting
