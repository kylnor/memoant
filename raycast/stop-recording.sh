#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Stop Recording
# @raycast.mode fullOutput
# @raycast.icon ⏹️
# @raycast.packageName Memoant

# Documentation:
# @raycast.description Stop current recording and process with transcription
# @raycast.author Kyle Northup

cd ~/Code/memoant && uv run memoant stop
