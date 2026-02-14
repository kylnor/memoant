import { Detail, ActionPanel, Action, Icon } from "@raycast/api";
import { useState, useEffect } from "react";
import { exec } from "child_process";
import { getRecordingState, getScriptPath, formatDuration, RecordingState } from "./shared";

export default function Command() {
  const [state, setState] = useState<RecordingState | null>(null);

  useEffect(() => {
    const update = () => setState(getRecordingState());
    update();

    const interval = setInterval(update, 1000);
    return () => clearInterval(interval);
  }, []);

  if (!state) {
    return <Detail isLoading={true} />;
  }

  let markdown: string;

  if (state.isRecording) {
    const duration = state.durationSeconds ? formatDuration(state.durationSeconds) : "0:00";
    const mode = state.mode === "screen" ? "Screen" : "Audio";
    markdown = [
      "# Recording in Progress",
      "",
      `| Field | Value |`,
      `|-------|-------|`,
      `| **Mode** | ${mode} |`,
      `| **Duration** | ${duration} |`,
      `| **PID** | ${state.pid} |`,
      state.filePath ? `| **File** | \`${state.filePath}\` |` : "",
    ]
      .filter(Boolean)
      .join("\n");
  } else {
    markdown = [
      "# No Active Recording",
      "",
      "Use **Record Audio** or **Record Screen** to start a new recording.",
    ].join("\n");
  }

  return (
    <Detail
      markdown={markdown}
      actions={
        <ActionPanel>
          {state.isRecording ? (
            <Action
              icon={Icon.Stop}
              title="Stop Recording"
              onAction={() => {
                const scriptPath = getScriptPath();
                exec(`"${scriptPath}" stop`);
              }}
            />
          ) : null}
          <Action
            icon={Icon.ArrowClockwise}
            title="Refresh"
            onAction={() => setState(getRecordingState())}
          />
        </ActionPanel>
      }
    />
  );
}
