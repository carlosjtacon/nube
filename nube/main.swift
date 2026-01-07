import Cocoa
import SwiftUI

// SwiftUI view for the status bar icon
struct StatusBarIconView: View {
    let status: AppDelegate.SyncStatus
    
    var body: some View {
        Group {
            switch status {
            case .idle:
                Image(systemName: "icloud.fill")
                    .symbolRenderingMode(.monochrome)
            case .syncing:
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill")
                    .symbolRenderingMode(.monochrome)
                    .symbolEffect(.rotate.byLayer, options: .repeat(.continuous))
            case .error:
                Image(systemName: "icloud.slash.fill")
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.red)
            }
        }
        .font(.system(size: 16, weight: .bold))
        .frame(width: 18, height: 18)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var hostingView: NSHostingView<StatusBarIconView>?
    
    // Sync status
    enum SyncStatus {
        case idle
        case syncing
        case error
    }
    
    var syncStatus: SyncStatus = .idle {
        didSet {
            updateIcon()
        }
    }
    
    // Mock data for prototype
    var recentFiles = [
        "Project Proposal.pdf",
        "Meeting Notes.docx",
        "Screenshot 2024.png",
        "Budget 2024.xlsx",
        "Presentation.key"
    ]
    
    var uploadSpeed = "1.2 MB/s"
    var downloadSpeed = "3.4 MB/s"
    var uploadingFiles = 3
    var downloadingFiles = 7
    var uploadPending = 0.5 // GB
    var downloadPending = 1.8 // GB
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with fixed width for padding
        statusItem = NSStatusBar.system.statusItem(withLength: 18)
        
        // Set initial icon
        updateIcon()
        
        // Build the menu
        buildMenu()
        
        // Update menu periodically (simulate real-time updates)
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateMockData()
            self?.buildMenu()
        }
        
        // Simulate status changes for demo purposes
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.simulateStatusChange()
        }
        
        // Start in syncing state for demo
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.syncStatus = .syncing
        }
    }
    
    func updateIcon() {
        guard let button = statusItem.button else { return }
        
        // Remove old hosting view if exists
        hostingView?.removeFromSuperview()
        
        // Create SwiftUI hosting view with icon
        let iconView = StatusBarIconView(status: syncStatus)
        hostingView = NSHostingView(rootView: iconView)
        hostingView?.frame = NSRect(x: 0, y: 0, width: 18, height: 18)
        
        // Add to button
        button.subviews.forEach { $0.removeFromSuperview() }
        if let hostingView = hostingView {
            button.addSubview(hostingView)
            hostingView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                hostingView.widthAnchor.constraint(equalToConstant: 18),
                hostingView.heightAnchor.constraint(equalToConstant: 18)
            ])
        }
    }
    
    func simulateStatusChange() {
        // Randomly change status for demo
        let statuses: [SyncStatus] = [.idle, .syncing, .syncing, .idle, .error]
        syncStatus = statuses.randomElement()!
        
        print("Status changed to: \(syncStatus)")
    }
    
    func buildMenu() {
        let menu = NSMenu()
        
        // === RECENTS SECTION ===
        let recentsHeader = NSMenuItem(title: "Recent Files", action: nil, keyEquivalent: "")
        recentsHeader.isEnabled = false
        menu.addItem(recentsHeader)
        
        for (index, fileName) in recentFiles.enumerated() {
            let fileItem = NSMenuItem(title: "  \(fileName)", action: #selector(openRecentFile(_:)), keyEquivalent: "")
            fileItem.tag = index
            fileItem.target = self
            menu.addItem(fileItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // === NETWORK SECTION ===
        let networkHeader = NSMenuItem(title: "Network Activity", action: nil, keyEquivalent: "")
        networkHeader.isEnabled = false
        menu.addItem(networkHeader)
        
        // Upload item
        let uploadItem = NSMenuItem(title: "  ↑ Upload: \(uploadSpeed)", action: nil, keyEquivalent: "")
        uploadItem.isEnabled = false
        menu.addItem(uploadItem)
        
        let uploadDetails = NSMenuItem(title: "     \(uploadingFiles) files • \(String(format: "%.1f", uploadPending)) GB pending", action: nil, keyEquivalent: "")
        uploadDetails.isEnabled = false
        menu.addItem(uploadDetails)
        
        // Download item
        let downloadItem = NSMenuItem(title: "  ↓ Download: \(downloadSpeed)", action: nil, keyEquivalent: "")
        downloadItem.isEnabled = false
        menu.addItem(downloadItem)
        
        let downloadDetails = NSMenuItem(title: "     \(downloadingFiles) files • \(String(format: "%.1f", downloadPending)) GB pending", action: nil, keyEquivalent: "")
        downloadDetails.isEnabled = false
        menu.addItem(downloadDetails)
        
        menu.addItem(NSMenuItem.separator())
        
        // === ACTION BUTTONS ===
        let openFolderItem = NSMenuItem(title: "Open iCloud Drive Folder", action: #selector(openICloudFolder), keyEquivalent: "o")
        openFolderItem.target = self
        menu.addItem(openFolderItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc func openRecentFile(_ sender: NSMenuItem) {
        let fileName = recentFiles[sender.tag]
        let alert = NSAlert()
        alert.messageText = "Open Recent File"
        alert.informativeText = "Would open: \(fileName)"
        alert.runModal()
        
        // In real implementation, you would:
        // NSWorkspace.shared.open(fileURL)
    }
    
    @objc func openICloudFolder() {
        // Open the iCloud Drive folder in Finder
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let iCloudPath = homeDirectory.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        
        if FileManager.default.fileExists(atPath: iCloudPath.path) {
            NSWorkspace.shared.open(iCloudPath)
        } else {
            let alert = NSAlert()
            alert.messageText = "iCloud Drive Not Found"
            alert.informativeText = "Could not locate iCloud Drive folder."
            alert.runModal()
        }
    }
    
    // Simulate changing data for prototype
    func updateMockData() {
        // Randomize speeds
        uploadSpeed = String(format: "%.1f MB/s", Double.random(in: 0.1...5.0))
        downloadSpeed = String(format: "%.1f MB/s", Double.random(in: 0.1...8.0))
        
        // Randomize pending counts
        uploadingFiles = Int.random(in: 0...10)
        downloadingFiles = Int.random(in: 0...15)
        uploadPending = Double.random(in: 0...3.0)
        downloadPending = Double.random(in: 0...5.0)
        
        // Rotate recent files (simulate new files)
        if Bool.random() {
            let newFiles = [
                "Document \(Int.random(in: 1...100)).pdf",
                "Image \(Int.random(in: 1...100)).jpg",
                "Data \(Int.random(in: 1...100)).csv"
            ]
            recentFiles.removeLast()
            recentFiles.insert(newFiles.randomElement()!, at: 0)
        }
        
        print("Updated mock data - Upload: \(uploadSpeed), Download: \(downloadSpeed)")
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

/*
 PROTOTYPE FEATURES:
 
 ✅ Dynamic icon with SwiftUI symbol effects:
    - Idle: Static cloud icon (bold)
    - Syncing: Rotating sync arrows with smooth animation
    - Error: Red cloud with slash (bold)
 ✅ Recents Section: 5 recent files (mock data, updates every 5 seconds)
 ✅ Network Section: Upload/download speeds with file counts and GB pending
 ✅ Open iCloud Folder button
 ✅ Quit button
 
 The app automatically changes status every 10 seconds to demo the animation.
 The syncing icon now uses SwiftUI's .symbolEffect(.rotate) for smooth rotation!
 
 TO USE IN REAL APP:
 Simply set syncStatus property based on actual iCloud sync state:
 
 syncStatus = .syncing  // Smooth rotating animation
 syncStatus = .idle     // Static cloud icon
 syncStatus = .error    // Red error icon
 */
