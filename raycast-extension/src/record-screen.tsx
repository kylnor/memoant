import { showHUD, showToast, Toast } from "@raycast/api";
import { spawn } from "child_process";
import { writeFileSync, mkdirSync, existsSync } from "fs";
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

  // Use spawn with detached + unref so the recording survives Raycast's lifecycle
  const child = spawn(scriptPath, ["screen"], {
    detached: true,
    stdio: "ignore",
    env: { ...process.env, HOME: process.env.HOME || "" },
  });
  child.unref();

  await showHUD("Starting screen recording... (select a window)");
}
