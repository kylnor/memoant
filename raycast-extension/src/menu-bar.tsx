import { MenuBarExtra, Icon, open, launchCommand, LaunchType } from "@raycast/api";
import { useState, useEffect } from "react";
import { exec } from "child_process";
import { writeFileSync, mkdirSync, existsSync } from "fs";
import { getRecordingState, getScriptPath, formatDuration, RecordingState } from "./shared";

export default function Command() {
  const [state, setState] = useState<RecordingState>({
    isRecording: false,
    pid: null,
    mode: null,
    filePath: null,
    startTime: null,
    durationSeconds: null,
  });

  useEffect(() => {
    const update = () => setState(getRecordingState());
    update();

    const interval = setInterval(update, 2000);
    return () => clearInterval(interval);
  }, []);

  const title = state.isRecording && state.durationSeconds != null
    ? formatDuration(state.durationSeconds)
    : undefined;

  const icon = state.isRecording
    ? { source: Icon.Microphone, tintColor: { light: "#FF3B30", dark: "#FF453A" } }
    : Icon.Microphone;

  const tooltip = state.isRecording
    ? `Recording ${state.mode || "audio"} - ${title || "..."}`
    : "Memoant - Not recording";

  return (
    <MenuBarExtra icon={icon} title={title} tooltip={tooltip}>
      {state.isRecording ? (
        <>
          <MenuBarExtra.Item
            icon={Icon.CircleFilled}
            title={`Recording ${state.mode === "screen" ? "Screen" : "Audio"}`}
          />
          {state.durationSeconds != null && (
            <MenuBarExtra.Item title={`Duration: ${formatDuration(state.durationSeconds)}`} />
          )}
          <MenuBarExtra.Separator />
          <MenuBarExtra.Item
            icon={Icon.Stop}
            title="Stop Recording"
            onAction={() => {
              const scriptPath = getScriptPath();
              exec(`"${scriptPath}" stop`);
            }}
          />
        </>
      ) : (
        <>
          <MenuBarExtra.Item
            icon={Icon.Microphone}
            title="Record Audio"
            onAction={() => {
              ensureTempDir();
              writeFileSync("/tmp/meeting-recorder/recording.start", String(Date.now()));
              const scriptPath = getScriptPath();
              exec(`"${scriptPath}" audio`);
            }}
          />
          <MenuBarExtra.Item
            icon={Icon.Desktop}
            title="Record Screen"
            onAction={() => {
              ensureTempDir();
              writeFileSync("/tmp/meeting-recorder/recording.start", String(Date.now()));
              const scriptPath = getScriptPath();
              exec(`"${scriptPath}" screen`);
            }}
          />
        </>
      )}
      <MenuBarExtra.Separator />
      <MenuBarExtra.Item
        icon={Icon.List}
        title="Meeting History"
        onAction={() => {
          launchCommand({ name: "meeting-history", type: LaunchType.UserInitiated });
        }}
      />
      <MenuBarExtra.Item
        icon={Icon.Info}
        title="Recording Status"
        onAction={() => {
          launchCommand({ name: "recording-status", type: LaunchType.UserInitiated });
        }}
      />
    </MenuBarExtra>
  );
}

function ensureTempDir() {
  const dir = "/tmp/meeting-recorder";
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}
