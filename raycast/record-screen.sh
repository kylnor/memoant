#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Record Screen Meeting
# @raycast.mode compact
# @raycast.icon 🎥
# @raycast.packageName Memoant

# Documentation:
# @raycast.description Start recording screen meeting with window selection and automatic transcription
# @raycast.author Kyle Northup

cd ~/Code/memoant && uv run memoant record --screen
