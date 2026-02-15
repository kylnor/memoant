import { getPreferenceValues } from "@raycast/api";
import { existsSync, readFileSync, statSync } from "fs";
import { execSync } from "child_process";
import { homedir } from "os";

interface Preferences {
  meetingsPath: string;
  scriptPath: string;
}

const TEMP_DIR = "/tmp/meeting-recorder";
const PID_FILE = `${TEMP_DIR}/recording.pid`;
const MODE_FILE = `${TEMP_DIR}/recording.mode`;
const RECORDING_FILE = `${TEMP_DIR}/recording.path`;
const START_TIME_FILE = `${TEMP_DIR}/recording.start`;

export function getPrefs(): Preferences {
  return getPreferenceValues<Preferences>();
}

export function getScriptPath(): string {
  const prefs = getPrefs();
  return prefs.scriptPath.replace("~", homedir());
}

export function getMeetingsPath(): string {
  const prefs = getPrefs();
  let path = prefs.meetingsPath;

  // If using default, check memoant config for user-configured path
  if (path === "~/Documents/Memoant/Notes") {
    const configPath = `${homedir()}/.config/memoant/config`;
    if (existsSync(configPath)) {
      const config = readFileSync(configPath, "utf-8");
      const match = config.match(/^MEMOANT_NOTES_DIR="(.+)"$/m);
      if (match) {
        path = match[1];
      }
    }
  }

  return path.replace("~", homedir()).replace("$HOME", homedir());
}

export interface RecordingState {
  isRecording: boolean;
  pid: number | null;
  mode: string | null;
  filePath: string | null;
  startTime: Date | null;
  durationSeconds: number | null;
}

export function getRecordingState(): RecordingState {
  const state: RecordingState = {
    isRecording: false,
    pid: null,
    mode: null,
    filePath: null,
    startTime: null,
    durationSeconds: null,
  };

  if (!existsSync(PID_FILE)) {
    return state;
  }

  try {
    const pid = parseInt(readFileSync(PID_FILE, "utf-8").trim(), 10);

    // Verify the process is actually running
    try {
      execSync(`kill -0 ${pid} 2>/dev/null`, { stdio: "ignore" });
    } catch {
      // Process is dead, clean up stale PID file
      return state;
    }

    state.isRecording = true;
    state.pid = pid;

    if (existsSync(MODE_FILE)) {
      state.mode = readFileSync(MODE_FILE, "utf-8").trim();
    }

    if (existsSync(RECORDING_FILE)) {
      state.filePath = readFileSync(RECORDING_FILE, "utf-8").trim();
    }

    if (existsSync(START_TIME_FILE)) {
      const startMs = parseInt(readFileSync(START_TIME_FILE, "utf-8").trim(), 10);
      state.startTime = new Date(startMs);
      state.durationSeconds = Math.floor((Date.now() - startMs) / 1000);
    } else {
      // Fall back to PID file modification time
      const pidStat = statSync(PID_FILE);
      state.startTime = pidStat.mtime;
      state.durationSeconds = Math.floor((Date.now() - pidStat.mtime.getTime()) / 1000);
    }
  } catch {
    // Something went wrong reading state
  }

  return state;
}

export function formatDuration(seconds: number): string {
  const hrs = Math.floor(seconds / 3600);
  const mins = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hrs > 0) {
    return `${hrs}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  }
  return `${mins}:${String(secs).padStart(2, "0")}`;
}

export interface MeetingNote {
  filename: string;
  filepath: string;
  title: string;
  date: string;
  tags: string[];
  summary: string;
  actionItems: string[];
  keyPoints: string[];
  decisions: string[];
  transcript: string;
  recording: string;
}

export function parseMeetingNote(filepath: string): MeetingNote | null {
  try {
    const content = readFileSync(filepath, "utf-8");
    const filename = filepath.split("/").pop() || "";

    // Parse YAML frontmatter
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
    let title = filename.replace(".md", "");
    let date = "";
    let tags: string[] = [];
    let recording = "";

    if (frontmatterMatch) {
      const fm = frontmatterMatch[1];

      const titleMatch = fm.match(/^title:\s*(.+)$/m);
      if (titleMatch) title = titleMatch[1].trim();

      const dateMatch = fm.match(/^date:\s*(.+)$/m);
      if (dateMatch) date = dateMatch[1].trim();

      const tagsMatch = fm.match(/^tags:\s*\[(.+)\]$/m);
      if (tagsMatch) {
        tags = tagsMatch[1].split(",").map((t) => t.trim().replace(/"/g, ""));
      }

      const recordingMatch = fm.match(/^recording:\s*"?(.+?)"?\s*$/m);
      if (recordingMatch) recording = recordingMatch[1];
    }

    // Parse body sections
    const body = frontmatterMatch ? content.slice(frontmatterMatch[0].length) : content;

    const summary = extractSection(body, "Summary");
    const actionItems = extractListSection(body, "Action Items");
    const keyPoints = extractListSection(body, "Key Points");
    const decisions = extractListSection(body, "Decisions Made");
    const transcript = extractSection(body, "Transcript");

    return {
      filename,
      filepath,
      title,
      date,
      tags,
      summary,
      actionItems,
      keyPoints,
      decisions,
      transcript,
      recording,
    };
  } catch {
    return null;
  }
}

function extractSection(body: string, heading: string): string {
  const regex = new RegExp(`## ${heading}\\n([\\s\\S]*?)(?=\\n## |$)`);
  const match = body.match(regex);
  return match ? match[1].trim() : "";
}

function extractListSection(body: string, heading: string): string[] {
  const text = extractSection(body, heading);
  if (!text) return [];
  return text
    .split("\n")
    .filter((line) => line.startsWith("- "))
    .map((line) => line.replace(/^- \[[ x]\] /, "").replace(/^- /, ""));
}
