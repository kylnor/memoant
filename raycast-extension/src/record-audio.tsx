import { showHUD, showToast, Toast } from "@raycast/api";
import { exec } from "child_process";
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

  exec(`"${scriptPath}" audio`, (error, _stdout, stderr) => {
    if (error) {
      console.error("Recording error:", stderr);
    }
  });

  await showHUD("Recording audio...");
}
