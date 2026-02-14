import { List, ActionPanel, Action, Detail, Icon, Color } from "@raycast/api";
import { useState, useEffect } from "react";
import { readdirSync } from "fs";
import { join } from "path";
import { getMeetingsPath, parseMeetingNote, MeetingNote } from "./shared";

export default function Command() {
  const [meetings, setMeetings] = useState<MeetingNote[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const meetingsPath = getMeetingsPath();
    try {
      const files = readdirSync(meetingsPath)
        .filter((f) => f.endsWith(".md"))
        .sort()
        .reverse();

      const parsed: MeetingNote[] = [];
      for (const file of files) {
        const note = parseMeetingNote(join(meetingsPath, file));
        if (note) {
          parsed.push(note);
        }
      }
      setMeetings(parsed);
    } catch (err) {
      console.error("Failed to read meetings:", err);
    }
    setIsLoading(false);
  }, []);

  return (
    <List isLoading={isLoading} searchBarPlaceholder="Search meetings...">
      {meetings.length === 0 && !isLoading ? (
        <List.EmptyView icon={Icon.Calendar} title="No meetings found" description="Record your first meeting to see it here." />
      ) : (
        meetings.map((meeting) => (
          <List.Item
            key={meeting.filepath}
            icon={Icon.Calendar}
            title={meeting.title}
            subtitle={meeting.date ? formatDate(meeting.date) : undefined}
            accessories={meeting.tags.map((tag) => ({
              tag: { value: tag, color: Color.Blue },
            }))}
            actions={
              <ActionPanel>
                <Action.Push icon={Icon.Eye} title="View Details" target={<MeetingDetail meeting={meeting} />} />
                <Action.Open
                  icon={Icon.Document}
                  title="Open in Obsidian"
                  target={`obsidian://open?vault=kylnor&file=${encodeURIComponent(meeting.filepath)}`}
                />
                <Action.ShowInFinder title="Show Note in Finder" path={meeting.filepath} />
                <Action.CopyToClipboard
                  title="Copy Summary"
                  content={meeting.summary || "No summary available"}
                  shortcut={{ modifiers: ["cmd"], key: "c" }}
                />
              </ActionPanel>
            }
          />
        ))
      )}
    </List>
  );
}

function MeetingDetail({ meeting }: { meeting: MeetingNote }) {
  const parts: string[] = [];

  parts.push(`# ${meeting.title}`);
  if (meeting.date) {
    parts.push(`**Date:** ${formatDate(meeting.date)}`);
  }
  if (meeting.tags.length > 0) {
    parts.push(`**Tags:** ${meeting.tags.join(", ")}`);
  }
  parts.push("");

  if (meeting.summary) {
    parts.push("## Summary");
    parts.push(meeting.summary);
    parts.push("");
  }

  if (meeting.actionItems.length > 0) {
    parts.push("## Action Items");
    for (const item of meeting.actionItems) {
      parts.push(`- [ ] ${item}`);
    }
    parts.push("");
  }

  if (meeting.keyPoints.length > 0) {
    parts.push("## Key Points");
    for (const point of meeting.keyPoints) {
      parts.push(`- ${point}`);
    }
    parts.push("");
  }

  if (meeting.decisions.length > 0) {
    parts.push("## Decisions");
    for (const decision of meeting.decisions) {
      parts.push(`- ${decision}`);
    }
    parts.push("");
  }

  if (meeting.transcript) {
    parts.push("## Transcript");
    parts.push(meeting.transcript);
  }

  return (
    <Detail
      markdown={parts.join("\n")}
      actions={
        <ActionPanel>
          <Action.Open
            icon={Icon.Document}
            title="Open in Obsidian"
            target={`obsidian://open?vault=kylnor&file=${encodeURIComponent(meeting.filepath)}`}
          />
          <Action.ShowInFinder title="Show Note in Finder" path={meeting.filepath} />
          <Action.CopyToClipboard
            title="Copy Transcript"
            content={meeting.transcript || "No transcript available"}
          />
          <Action.CopyToClipboard
            title="Copy Summary"
            content={meeting.summary || "No summary available"}
            shortcut={{ modifiers: ["cmd"], key: "c" }}
          />
        </ActionPanel>
      }
    />
  );
}

function formatDate(dateStr: string): string {
  try {
    const d = new Date(dateStr);
    return d.toLocaleDateString("en-US", {
      weekday: "short",
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "numeric",
      minute: "2-digit",
    });
  } catch {
    return dateStr;
  }
}
