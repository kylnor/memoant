/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Meetings Folder - Path to Obsidian meetings folder */
  "meetingsPath": string,
  /** Script Path - Path to record-meeting.sh */
  "scriptPath": string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `record-audio` command */
  export type RecordAudio = ExtensionPreferences & {}
  /** Preferences accessible in the `record-screen` command */
  export type RecordScreen = ExtensionPreferences & {}
  /** Preferences accessible in the `stop-recording` command */
  export type StopRecording = ExtensionPreferences & {}
  /** Preferences accessible in the `meeting-history` command */
  export type MeetingHistory = ExtensionPreferences & {}
  /** Preferences accessible in the `recording-status` command */
  export type RecordingStatus = ExtensionPreferences & {}
  /** Preferences accessible in the `menu-bar` command */
  export type MenuBar = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `record-audio` command */
  export type RecordAudio = {}
  /** Arguments passed to the `record-screen` command */
  export type RecordScreen = {}
  /** Arguments passed to the `stop-recording` command */
  export type StopRecording = {}
  /** Arguments passed to the `meeting-history` command */
  export type MeetingHistory = {}
  /** Arguments passed to the `recording-status` command */
  export type RecordingStatus = {}
  /** Arguments passed to the `menu-bar` command */
  export type MenuBar = {}
}

