import { showHUD, showToast, Toast } from "@raycast/api";
import { exec } from "child_process";
import { existsSync, unlinkSync } from "fs";
import { getScriptPath, getRecordingState, formatDuration } from "./shared";

export default async function Command() {
  const state = getRecordingState();

  if (!state.isRecording) {
    await showHUD("No recording in progress");
    return;
  }

  const scriptPath = getScriptPath();
  const duration = state.durationSeconds ? formatDuration(state.durationSeconds) : "unknown";

  await showToast({
    style: Toast.Style.Animated,
    title: "Stopping recording...",
    message: `Duration: ${duration}. Processing will continue in background.`,
  });

  exec(`"${scriptPath}" stop`, (error, _stdout, stderr) => {
    if (error) {
      console.error("Stop error:", stderr);
    }
  });

  // Clean up start time file
  const startFile = "/tmp/meeting-recorder/recording.start";
  if (existsSync(startFile)) {
    try {
      unlinkSync(startFile);
    } catch {
      // ignore cleanup errors
    }
  }

  await showHUD(`Recording stopped (${duration}). Transcribing...`);
}
