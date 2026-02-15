import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "Memoant - Your meetings, remembered.",
  description:
    "A macOS meeting recorder that automatically transcribes with speaker diarization, extracts AI metadata, and organizes everything into Obsidian notes. All AI processing runs on your Mac.",
  keywords: [
    "meeting recorder",
    "transcription",
    "speaker diarization",
    "obsidian",
    "macOS",
    "whisperx",
    "ollama",
    "AI notes",
    "local processing",
    "privacy",
  ],
  authors: [{ name: "Kyle Northup" }],
  openGraph: {
    title: "Memoant - Your meetings, remembered.",
    description:
      "Auto-transcribe meetings with speaker ID, extract AI metadata, and organize into Obsidian notes. Everything runs locally.",
    type: "website",
    locale: "en_US",
    siteName: "Memoant",
  },
  twitter: {
    card: "summary_large_image",
    title: "Memoant - Your meetings, remembered.",
    description:
      "Auto-transcribe meetings with speaker ID, extract AI metadata, and organize into Obsidian notes. Everything runs locally.",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <head>
        <link rel="icon" href="/favicon.ico" sizes="any" />
        <link rel="apple-touch-icon" href="/apple-touch-icon.png" />
      </head>
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased`}
      >
        {children}
      </body>
    </html>
  );
}
