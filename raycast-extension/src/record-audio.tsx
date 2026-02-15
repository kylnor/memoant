import { showHUD, showToast, Toast } from "@raycast/api";
import { spawn } from "child_process";
import { writeFileSync, mkdirSync, existsSync, openSync } from "fs";
import { getScriptPath, getRecordingState } from "./shared";

export default async function Command() {
  const state = getRecordingState();

  if (state.isRecording) {
    await showHUD("Already recording (" + (state.mode || "unknown") + " mode)");
    return;
  }

  const scriptPath = getScriptPath();

  if (!existsSync(scriptPath)) {
    await showToast({
      style: Toast.Style.Failure,
      title: "Script not found",
      message: scriptPath,
    });
    return;
  }

  // Write start time for duration tracking
  const tempDir = "/tmp/meeting-recorder";
  if (!existsSync(tempDir)) {
    mkdirSync(tempDir, { recursive: true });
  }
  writeFileSync(`${tempDir}/recording.start`, String(Date.now()));

  // Log output for debugging
  const logFd = openSync("/tmp/meeting-recorder/start.log", "w");

  // Use spawn with detached + unref so the recording survives Raycast's lifecycle
  const child = spawn(scriptPath, ["audio"], {
    detached: true,
    stdio: ["ignore", logFd, logFd],
    env: { ...process.env, HOME: process.env.HOME || "" },
  });
  child.unref();

  // Give the script a moment to start and write PID file
  await new Promise((resolve) => setTimeout(resolve, 1500));

  const newState = getRecordingState();
  if (newState.isRecording) {
    await showHUD("Recording audio...");
  } else {
    await showToast({
      style: Toast.Style.Failure,
      title: "Recording failed to start",
      message: "Check ~/Code/meeting-recorder for logs",
    });
  }
}
