import { showHUD, showToast, Toast } from "@raycast/api";
import { spawn } from "child_process";
import { existsSync, unlinkSync, openSync } from "fs";
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

  // Log output to file so we can debug failures
  const logFile = "/tmp/meeting-recorder/stop.log";
  const logFd = openSync(logFile, "w");

  // Use spawn with detached so transcription can continue even if Raycast times out
  const child = spawn(scriptPath, ["stop"], {
    detached: true,
    stdio: ["ignore", logFd, logFd],
    env: { ...process.env, HOME: process.env.HOME || "" },
  });
  child.unref();

  // Clean up start time file
  const startFile = "/tmp/meeting-recorder/recording.start";
  if (existsSync(startFile)) {
    try {
      unlinkSync(startFile);
    } catch {
      // ignore cleanup errors
    }
  }

  await showHUD(`Recording stopped (${duration}). Transcribing in background...`);
}
