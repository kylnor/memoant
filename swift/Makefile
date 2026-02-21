# Memoant Swift binaries (ScreenCaptureKit)
# Requires macOS 12.3+

PREFIX ?= .

all: $(PREFIX)/WindowRecorder $(PREFIX)/WindowPicker

$(PREFIX)/WindowRecorder: WindowRecorder.swift
	swiftc -O -o $@ $< \
		-framework ScreenCaptureKit \
		-framework AVFoundation \
		-framework AppKit

$(PREFIX)/WindowPicker: WindowPickerThumbs.swift
	swiftc -O -o $@ $< \
		-framework ScreenCaptureKit \
		-framework Cocoa

clean:
	rm -f $(PREFIX)/WindowRecorder $(PREFIX)/WindowPicker

.PHONY: all clean
