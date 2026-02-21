import Cocoa
import ScreenCaptureKit

@available(macOS 12.3, *)
class WindowItem: NSObject {
    let window: SCWindow
    var thumbnail: NSImage?
    var isDesktop: Bool = false

    init(window: SCWindow) {
        self.window = window
        super.init()
    }

    var title: String {
        if isDesktop {
            return "Desktop (Entire Screen)"
        }
        let appName = window.owningApplication?.applicationName ?? "Unknown"
        let windowTitle = window.title ?? "Untitled"
        return "\(appName) - \(windowTitle)"
    }
}

// Custom ImageView that fills frame with aspect-fill behavior
class AspectFillImageView: NSImageView {
    private var cachedLayer: CALayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
    }

    override var image: NSImage? {
        didSet {
            updateLayerContents()
        }
    }

    private func updateLayerContents() {
        guard let image = image else {
            layer?.contents = nil
            return
        }

        // Set the image directly on the layer with aspect fill
        layer?.contents = image
        layer?.contentsGravity = .resizeAspectFill
    }

    override func layout() {
        super.layout()
        updateLayerContents()
    }
}

@available(macOS 12.3, *)
class WindowCollectionViewItem: NSCollectionViewItem {
    private var thumbnailView: AspectFillImageView!
    private var nameLabel: NSTextField!
    private var overlayView: NSView!

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailView.image = nil
        nameLabel.stringValue = ""
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 180))

        // Container for border
        overlayView = NSView(frame: NSRect(x: 5, y: 25, width: 210, height: 140))
        overlayView.wantsLayer = true
        overlayView.layer?.cornerRadius = 8
        overlayView.layer?.borderWidth = 3
        overlayView.layer?.borderColor = NSColor.clear.cgColor

        // Thumbnail image - custom aspect fill view
        thumbnailView = AspectFillImageView(frame: NSRect(x: 8, y: 28, width: 204, height: 134))
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 6
        thumbnailView.layer?.masksToBounds = true
        thumbnailView.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1.0).cgColor

        // Title label
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.frame = NSRect(x: 5, y: 5, width: 210, height: 18)
        nameLabel.font = NSFont.systemFont(ofSize: 11)
        nameLabel.textColor = .labelColor
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingTail

        view.addSubview(overlayView)
        view.addSubview(thumbnailView)
        view.addSubview(nameLabel)
    }

    override var isSelected: Bool {
        didSet {
            if isSelected {
                overlayView.layer?.borderColor = NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0).cgColor
            } else {
                overlayView.layer?.borderColor = NSColor.clear.cgColor
            }
        }
    }

    func configure(with item: WindowItem) {
        nameLabel.stringValue = item.title
        if let thumb = item.thumbnail {
            thumbnailView.image = thumb
        }
    }
}

@available(macOS 12.3, *)
class WindowPickerController: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
    var windows: [WindowItem] = []
    var selectedIndex: Int = 0
    var windowToShow: NSWindow!
    var collectionView: NSCollectionView!

    func showPicker() async -> String? {
        // Get available windows
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )

            // Add Desktop option first (special placeholder)
            let desktopItem = WindowItem(window: availableContent.windows.first!)
            desktopItem.isDesktop = true

            // Capture desktop screenshot at lower resolution
            if let display = availableContent.displays.first {
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = 400  // Lower resolution for smooth scrolling
                config.height = 300

                if let screenshot = try? await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                ) {
                    desktopItem.thumbnail = NSImage(cgImage: screenshot, size: .zero)
                }
            }

            windows.append(desktopItem)

            let filteredWindows = availableContent.windows.filter { window in
                guard let title = window.title,
                      !title.isEmpty,
                      let app = window.owningApplication else {
                    return false
                }

                // Filter out system UI
                let appName = app.applicationName
                let excludedApps = ["Dock", "Window Server", "SystemUIServer", "Notification Center"]
                if excludedApps.contains(appName) {
                    return false
                }

                // Filter out desktop/wallpaper/backstop windows
                let excludedTitles = ["Wallpaper", "Desktop", "Backstop", "Item-0", "Notification"]
                if excludedTitles.contains(where: { title.contains($0) }) {
                    return false
                }

                // Filter out likely invisible/overlay windows
                let excludedKeywords = ["underbelly", "Annotation", "Overlay", "Helper", "Agent"]
                if excludedKeywords.contains(where: { title.lowercased().contains($0.lowercased()) }) {
                    return false
                }

                // Only show reasonably sized windows (bigger threshold)
                return window.frame.width > 200 && window.frame.height > 150
            }

            // Create window items and capture thumbnails
            for window in filteredWindows {
                let item = WindowItem(window: window)

                // Capture thumbnail at lower resolution for performance
                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = 400  // Lower resolution
                config.height = 300

                if let screenshot = try? await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                ) {
                    item.thumbnail = NSImage(cgImage: screenshot, size: .zero)
                }

                windows.append(item)
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
    func createAndShowWindow() -> String? {
        // Create window - sized for exactly 3 columns
        // Math: (220 * 3) + (10 * 2) + 40 margins = 720px scrollview, 760px window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Memoant - Window Recorder"
        window.center()
        window.appearance = NSAppearance(named: .darkAqua)

        // Create content view
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1.0).cgColor

        // Title label
        let titleLabel = NSTextField(labelWithString: "Select a window to record:")
        titleLabel.font = NSFont.systemFont(ofSize: 13)
        titleLabel.textColor = .labelColor
        titleLabel.frame = NSRect(x: 20, y: 550, width: 720, height: 20)
        contentView.addSubview(titleLabel)

        // Create collection view with flow layout - exactly 3 columns
        let layout = NSCollectionViewFlowLayout()
        layout.itemSize = NSSize(width: 220, height: 180)
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 15
        layout.sectionInset = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)

        // Scrollview for collection - sized for 3 columns exactly
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 70, width: 720, height: 460))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        scrollView.usesPredominantAxisScrolling = false
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none
        scrollView.scrollerKnobStyle = .default

        // Increase scroll speed
        scrollView.verticalScroller?.scrollerStyle = .overlay
        scrollView.scrollerInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        // Performance optimizations
        scrollView.wantsLayer = true
        scrollView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        scrollView.drawsBackground = false

        collectionView = NSCollectionView(frame: scrollView.bounds)
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [NSColor(white: 0.15, alpha: 1.0)]

        // Enable layer backing for smooth scrolling
        collectionView.wantsLayer = true
        collectionView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        collectionView.layerContentsPlacement = .scaleAxesIndependently

        collectionView.register(
            WindowCollectionViewItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("WindowItem")
        )

        scrollView.documentView = collectionView
        contentView.addSubview(scrollView)

        // Buttons
        let cancelButton = NSButton(frame: NSRect(x: 550, y: 20, width: 90, height: 32))
        cancelButton.title = "Cancel"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        cancelButton.keyEquivalent = "\u{1b}" // Escape key
        contentView.addSubview(cancelButton)

        let recordButton = NSButton(frame: NSRect(x: 650, y: 20, width: 90, height: 32))
        recordButton.title = "Record"
        recordButton.bezelStyle = .rounded
        recordButton.target = self
        recordButton.action = #selector(recordClicked)
        recordButton.keyEquivalent = "\r" // Return key

        // Red tint for record button
        recordButton.contentTintColor = NSColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 1.0)
        contentView.addSubview(recordButton)

        window.contentView = contentView
        windowToShow = window

        // Select first item by default
        if !windows.isEmpty {
            collectionView.selectItems(
                at: Set([IndexPath(item: 0, section: 0)]),
                scrollPosition: .top
            )
            selectedIndex = 0
        }

        // Run modal
        NSApp.activate(ignoringOtherApps: true)
        let response = NSApp.runModal(for: window)

        window.close()

        if response == .OK {
            let item = windows[selectedIndex]
            if item.isDesktop {
                return "desktop"
            }
            return "id:\(item.window.windowID)"
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

    // MARK: - NSCollectionViewDataSource

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return windows.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("WindowItem"),
            for: indexPath
        ) as! WindowCollectionViewItem

        item.configure(with: windows[indexPath.item])

        return item
    }

    // MARK: - NSCollectionViewDelegate

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        if let indexPath = indexPaths.first {
            selectedIndex = indexPath.item
        }
    }
}

// MARK: - Main Entry Point

if #available(macOS 12.3, *) {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)

    Task {
        let picker = WindowPickerController()

        if let selection = await picker.showPicker() {
            print(selection)
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
