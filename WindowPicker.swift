import Cocoa
import ScreenCaptureKit

@available(macOS 12.3, *)
class WindowPickerController: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var windows: [SCWindow] = []
    var selectedIndex: Int = 0
    var windowToShow: NSWindow!
    var tableView: NSTableView!

    func showPicker() async -> Int? {
        // Get available windows
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            windows = availableContent.windows.filter { window in
                window.title != nil &&
                !window.title!.isEmpty &&
                window.frame.width > 100 &&
                window.frame.height > 100 &&
                window.owningApplication != nil
            }

            guard !windows.isEmpty else {
                print("No recordable windows found")
                return nil
            }

        } catch {
            print("Error getting windows: \(error)")
            return nil
        }

        // Create and show window on main thread
        return await MainActor.run {
            createAndShowWindow()
        }
    }

    @MainActor
    func createAndShowWindow() -> Int? {
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Memoant - Window Recorder"
        window.center()
        window.appearance = NSAppearance(named: .darkAqua)

        // Create content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))

        // Title label
        let titleLabel = NSTextField(labelWithString: "Select a window to record:")
        titleLabel.font = NSFont.systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: 450, width: 560, height: 20)
        contentView.addSubview(titleLabel)

        // Create scrollview for table
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 70, width: 560, height: 360))
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false

        // Create table view
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.backgroundColor = NSColor(white: 0.15, alpha: 1.0)
        tableView.rowHeight = 32
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = false

        // Add column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("WindowColumn"))
        column.width = 540
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Buttons
        let cancelButton = NSButton(frame: NSRect(x: 390, y: 20, width: 90, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        contentView.addSubview(cancelButton)

        let recordButton = NSButton(frame: NSRect(x: 490, y: 20, width: 90, height: 32))
        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(recordClicked)
        recordButton.keyEquivalent = "\r" // Return key

        // Make record button red like Zoom
        if let color = NSColor(named: NSColor.Name("systemRed")) {
            recordButton.contentTintColor = color
        }
        contentView.addSubview(recordButton)

        window.contentView = contentView
        windowToShow = window

        // Select first row by default
        tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        selectedIndex = 0

        // Run modal
        NSApp.activate(ignoringOtherApps: true)
        let response = NSApp.runModal(for: window)

        window.close()

        if response == .OK {
            return selectedIndex + 1 // Return 1-based index
        } else {
            return nil
        }
    }

    @objc func cancelClicked() {
        NSApp.stopModal(withCode: .cancel)
    }

    @objc func recordClicked() {
        NSApp.stopModal(withCode: .OK)
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int {
        return windows.count
    }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let window = windows[row]
        let appName = window.owningApplication?.applicationName ?? "Unknown"
        let windowTitle = window.title ?? "Untitled"

        let cellView = NSTableCellView()

        let textField = NSTextField(labelWithString: "\(row + 1). \(appName) - \(windowTitle)")
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.textColor = .labelColor
        textField.frame = NSRect(x: 10, y: 6, width: 520, height: 20)
        textField.lineBreakMode = .byTruncatingTail

        cellView.addSubview(textField)
        cellView.textField = textField

        return cellView
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedIndex = row
        return true
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = CustomTableRowView()
        return rowView
    }
}

// Custom row view for hover effect
class CustomTableRowView: NSTableRowView {
    override var isSelected: Bool {
        didSet {
            needsDisplay = true
        }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        if isSelected {
            NSColor(red: 0.8, green: 0.3, blue: 0.3, alpha: 0.6).setFill()
            let selectionRect = NSInsetRect(bounds, 2, 2)
            let path = NSBezierPath(roundedRect: selectionRect, xRadius: 4, yRadius: 4)
            path.fill()
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        if isSelected {
            // Selection is drawn in drawSelection
        } else {
            NSColor(white: 0.18, alpha: 1.0).setFill()
            dirtyRect.fill()
        }
    }
}

// MARK: - Main Entry Point

if #available(macOS 12.3, *) {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    Task {
        let picker = WindowPickerController()

        if let selectedIndex = await picker.showPicker() {
            print("\(selectedIndex)")
            exit(0)
        } else {
            exit(1)
        }
    }

    app.run()
} else {
    print("This tool requires macOS 12.3 or later")
    exit(1)
}
