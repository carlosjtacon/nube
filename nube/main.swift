import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var animationTimer: Timer?
    
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
    
    var animationFrame = 0
    
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
        // Create status bar item with cloud icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
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
        // Stop any existing animation
        animationTimer?.invalidate()
        animationTimer = nil
        
        guard let button = statusItem.button else { return }
        
        switch syncStatus {
        case .idle:
            button.image = NSImage(systemSymbolName: "icloud.fill", accessibilityDescription: "iCloud Drive - Idle")
            
        case .syncing:
            button.image = NSImage(systemSymbolName: "arrow.trianglehead.2.clockwise.rotate.90.icloud.fill", accessibilityDescription: "iCloud Drive - Syncing")
            
        case .error:
            button.image = NSImage(systemSymbolName: "icloud.slash.fill", accessibilityDescription: "iCloud Drive - Error")
        }
    }
    
    func animateSyncIcon() {
        // No longer needed - using static syncing icon
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
        let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
        
        // Fallback to user's iCloud Drive folder
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
 
 ✅ Dynamic icon based on sync status:
    - Idle: Static cloud icon
    - Syncing: Animated cloud with up/down arrows
    - Error: Cloud with slash
 ✅ Status indicator in menu
 ✅ Recents Section: 5 recent files (mock data, updates every 5 seconds)
 ✅ Network Section: Upload/download speeds with file counts and GB pending
 ✅ Open iCloud Folder button
 ✅ Quit button
 
 The app automatically changes status every 10 seconds to demo the animation.
 
 TO USE IN REAL APP:
 Simply set syncStatus property based on actual iCloud sync state:
 
 // When files start syncing:
 syncStatus = .syncing
 
 // When sync completes:
 syncStatus = .idle
 
 // When sync error occurs:
 syncStatus = .error
 
 NEXT STEPS FOR REAL IMPLEMENTATION:
 
 1. Access real iCloud Drive data:
    - Use NSMetadataQuery to monitor iCloud files
    - Track file download/upload status with NSMetadataItemDownloadingStatusKey
    
 2. Get actual network stats:
    - Monitor NSMetadataQuery notifications for file transfers
    - Calculate speeds based on file size changes over time
    
 3. Track recent files:
    - Query NSMetadataQuery with date sorting
    - Filter by NSMetadataItemFSContentChangeDateKey
    
 4. Enable iCloud capability:
    - In Xcode: Target → Signing & Capabilities → + Capability → iCloud
    - Enable "iCloud Documents"
    
 5. Add entitlements for iCloud access
 
 The prototype shows the UI structure with mock data that updates periodically.
 */
