"use client";

import { useEffect, useState } from "react";

const lines = [
  { text: "$ memoant record --mode audio", delay: 0, color: "text-teal" },
  { text: "Recording started... (system audio + microphone)", delay: 800, color: "text-muted" },
  { text: "", delay: 1600, color: "" },
  { text: "$ memoant stop", delay: 2400, color: "text-teal" },
  { text: "Recording stopped. Processing...", delay: 3200, color: "text-muted" },
  { text: "", delay: 3600, color: "" },
  { text: "Transcribing with WhisperX.............. done (42s)", delay: 4000, color: "text-coral" },
  { text: "Identifying speakers (pyannote)........ done (8s)", delay: 5000, color: "text-coral" },
  { text: "Extracting metadata (Ollama)........... done (12s)", delay: 6000, color: "text-coral" },
  { text: "", delay: 6800, color: "" },
  { text: "Subject:  Q1 Planning Review", delay: 7200, color: "text-foreground" },
  { text: "Speakers: 3 identified", delay: 7600, color: "text-foreground" },
  { text: "Tags:     #planning #q1 #roadmap #budget", delay: 8000, color: "text-foreground" },
  { text: "Actions:  4 items extracted", delay: 8400, color: "text-foreground" },
  { text: "", delay: 8800, color: "" },
  { text: "Saved: vault/Meetings/2026-02-14_q1-planning-review.md", delay: 9200, color: "text-teal" },
  { text: "Drive: Google Drive/Store/2026-02-14_q1-planning-review/", delay: 9600, color: "text-teal" },
];

export function TerminalDemo() {
  const [visibleLines, setVisibleLines] = useState(0);

  useEffect(() => {
    const timers: ReturnType<typeof setTimeout>[] = [];
    lines.forEach((line, i) => {
      timers.push(
        setTimeout(() => {
          setVisibleLines(i + 1);
        }, line.delay)
      );
    });
    return () => timers.forEach(clearTimeout);
  }, []);

  return (
    <div className="glass rounded-xl overflow-hidden text-left max-w-2xl mx-auto">
      {/* Title bar */}
      <div className="flex items-center gap-2 px-4 py-3 border-b border-border">
        <div className="w-3 h-3 rounded-full bg-[#ff5f57]" />
        <div className="w-3 h-3 rounded-full bg-[#febc2e]" />
        <div className="w-3 h-3 rounded-full bg-[#28c840]" />
        <span className="ml-2 text-xs text-muted font-mono">Terminal</span>
      </div>
      {/* Content */}
      <div className="p-5 font-mono text-sm leading-relaxed min-h-[340px]">
        {lines.slice(0, visibleLines).map((line, i) => (
          <div key={i} className={line.color || "text-foreground"}>
            {line.text || "\u00A0"}
          </div>
        ))}
        {visibleLines < lines.length && (
          <span className="inline-block w-2 h-4 bg-foreground cursor-blink" />
        )}
      </div>
    </div>
  );
}
