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

struct ICloudStatus {
    var isActive: Bool = false
    var recentFolders: [String] = []
    var folderPaths: [String: String] = [:] // folder name -> full path
    var uploadingFiles: Int = 0
    var downloadingFiles: Int = 0
    var uploadPendingGB: Double = 0.0
    var downloadPendingGB: Double = 0.0
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var hostingView: NSHostingView<StatusBarIconView>?
    var isCheckingStatus = false
    
    // Logging configuration
    let LOGGING_ENABLED = true
    var executionCounter = 0
    
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
    
    var iCloudStatus = ICloudStatus()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: 18)
        updateIcon()
        buildMenu()
        
        // Start the continuous check loop
        scheduleNextCheck()
    }
    
    func scheduleNextCheck() {
        // Wait 5 seconds, then check status
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.checkICloudStatus()
        }
    }
    
    func updateIcon() {
        guard let button = statusItem.button else { return }
        
        hostingView?.removeFromSuperview()
        
        let iconView = StatusBarIconView(status: syncStatus)
        hostingView = NSHostingView(rootView: iconView)
        hostingView?.frame = NSRect(x: 0, y: 0, width: 18, height: 18)
        
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
    
    func checkICloudStatus() {
        guard !isCheckingStatus else {
            if LOGGING_ENABLED {
                print("Already checking status, skipping...")
            }
            scheduleNextCheck()
            return
        }
        
        isCheckingStatus = true
        executionCounter += 1
        let currentExecution = executionCounter
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.launchPath = "/usr/bin/brctl"
            task.arguments = ["status", "com.apple.CloudDocs"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            task.launch()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                if self.LOGGING_ENABLED {
                    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                    print("=== brctl status output #\(currentExecution) at \(timestamp) ===")
                    print(output)
                    print("= #\(currentExecution) at \(timestamp) " + String(repeating: "=", count: 60))
                }
                
                DispatchQueue.main.async {
                    self.parseICloudStatus(output)
                    self.isCheckingStatus = false
                    
                    // Schedule the next check after this one completes
                    self.scheduleNextCheck()
                }
            } else {
                DispatchQueue.main.async {
                    self.isCheckingStatus = false
                    self.scheduleNextCheck()
                }
            }
        }
    }
    
    func parseICloudStatus(_ output: String) {
        var newStatus = ICloudStatus()
        var folderSet = Set<String>()
        var folderPathMap: [String: String] = [:]
        
        let lines = output.components(separatedBy: "\n")
        
        var totalUploadBytes: Int64 = 0
        var totalDownloadBytes: Int64 = 0
        
        var currentFolder: String? = nil
        var previousLine = ""
        
        for line in lines {
            // Track current folder
            if line.contains("Under /") {
                if let folderPath = line.components(separatedBy: "Under ").last?.trimmingCharacters(in: .whitespaces) {
                    currentFolder = folderPath
                }
            }
            
            // Skip trash items
            if let folder = currentFolder, folder.hasPrefix("/.Trash") {
                previousLine = line
                continue
            }
            
            // Check for uploading files
            if line.contains("> upload{") {
                newStatus.uploadingFiles += 1
                
                // Extract size from previous line
                if let sizeMatch = extractSize(from: previousLine) {
                    totalUploadBytes += sizeMatch
                }
            }
            
            // Check for downloading files
            if line.contains("> downloader{") {
                newStatus.downloadingFiles += 1
                
                // Extract size from previous line
                if let sizeMatch = extractSize(from: previousLine) {
                    totalDownloadBytes += sizeMatch
                }
            }
            
            // Add folder to set (excluding trash)
            if let folder = currentFolder, !folder.hasPrefix("/.Trash") {
                let folderName = (folder as NSString).lastPathComponent
                folderSet.insert(folderName)
                folderPathMap[folderName] = folder
            }
            
            previousLine = line
        }
        
        newStatus.uploadPendingGB = Double(totalUploadBytes) / 1_000_000_000.0
        newStatus.downloadPendingGB = Double(totalDownloadBytes) / 1_000_000_000.0
        
        // Check if there's activity
        let hasActivity = output.contains("Client Truth Unclean Items:")
        newStatus.isActive = hasActivity
        
        // Convert set to sorted array, limit to 5
        newStatus.recentFolders = Array(folderSet.sorted().prefix(5))
        newStatus.folderPaths = folderPathMap
        
        // Update sync status
        if hasActivity {
            syncStatus = .syncing
        } else {
            syncStatus = .idle
        }
        
        iCloudStatus = newStatus
        
        if LOGGING_ENABLED {
            print("Parsed status: Active=\(newStatus.isActive), Uploading=\(newStatus.uploadingFiles), Downloading=\(newStatus.downloadingFiles)")
            print("Upload GB: \(newStatus.uploadPendingGB), Download GB: \(newStatus.downloadPendingGB)")
            print("Folders: \(newStatus.recentFolders)")
        }
        
        buildMenu()
    }
    
    func extractSize(from line: String) -> Int64? {
        // Match patterns like "sz:596.9 MB (596911389)" or "sz:2.6 MB (2621139)"
        let pattern = "sz:[^(]+\\((\\d+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsString = line as NSString
        let results = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
        
        if let match = results.first, match.numberOfRanges > 1 {
            let sizeString = nsString.substring(with: match.range(at: 1))
            return Int64(sizeString)
        }
        
        return nil
    }
    
    func buildMenu() {
        let menu = NSMenu()
        
        // === RECENT FOLDERS SECTION ===
        if !iCloudStatus.recentFolders.isEmpty {
            let foldersHeader = NSMenuItem(title: "Recent Folders", action: nil, keyEquivalent: "")
            foldersHeader.isEnabled = false
            menu.addItem(foldersHeader)
            
            for (index, folder) in iCloudStatus.recentFolders.enumerated() {
                let folderItem = NSMenuItem(title: "  \(folder)", action: #selector(openFolder(_:)), keyEquivalent: "")
                folderItem.tag = index
                folderItem.target = self
                menu.addItem(folderItem)
            }
            
            menu.addItem(NSMenuItem.separator())
        }
        
        // === NETWORK SECTION ===
        let networkHeader = NSMenuItem(title: "Sync Activity", action: nil, keyEquivalent: "")
        networkHeader.isEnabled = false
        menu.addItem(networkHeader)
        
        // Upload item
        if iCloudStatus.uploadingFiles > 0 {
            let uploadItem = NSMenuItem(title: "  ↑ Uploading", action: nil, keyEquivalent: "")
            uploadItem.isEnabled = false
            menu.addItem(uploadItem)
            
            let uploadDetails = NSMenuItem(title: "     \(iCloudStatus.uploadingFiles) files • \(String(format: "%.2f", iCloudStatus.uploadPendingGB)) GB", action: nil, keyEquivalent: "")
            uploadDetails.isEnabled = false
            menu.addItem(uploadDetails)
        } else {
            let uploadItem = NSMenuItem(title: "  ↑ No uploads", action: nil, keyEquivalent: "")
            uploadItem.isEnabled = false
            menu.addItem(uploadItem)
        }
        
        // Download item
        if iCloudStatus.downloadingFiles > 0 {
            let downloadItem = NSMenuItem(title: "  ↓ Downloading", action: nil, keyEquivalent: "")
            downloadItem.isEnabled = false
            menu.addItem(downloadItem)
            
            let downloadDetails = NSMenuItem(title: "     \(iCloudStatus.downloadingFiles) files • \(String(format: "%.2f", iCloudStatus.downloadPendingGB)) GB", action: nil, keyEquivalent: "")
            downloadDetails.isEnabled = false
            menu.addItem(downloadDetails)
        } else {
            let downloadItem = NSMenuItem(title: "  ↓ No downloads", action: nil, keyEquivalent: "")
            downloadItem.isEnabled = false
            menu.addItem(downloadItem)
        }
        
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
    
    @objc func openFolder(_ sender: NSMenuItem) {
        let folderName = iCloudStatus.recentFolders[sender.tag]
        
        // Get the full path from the map
        guard let relativePath = iCloudStatus.folderPaths[folderName] else {
            if LOGGING_ENABLED {
                print("Could not find path for folder: \(folderName)")
            }
            return
        }
        
        // Build full iCloud path
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let iCloudBase = homeDirectory.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        let fullPath = iCloudBase.appendingPathComponent(relativePath)
        
        if LOGGING_ENABLED {
            print("Opening folder: \(fullPath.path)")
        }
        
        if FileManager.default.fileExists(atPath: fullPath.path) {
            NSWorkspace.shared.open(fullPath)
        } else {
            let alert = NSAlert()
            alert.messageText = "Folder Not Found"
            alert.informativeText = "Could not locate folder: \(folderName)"
            alert.runModal()
        }
    }
    
    @objc func openICloudFolder() {
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
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()

/*
 REAL IMPLEMENTATION with brctl:
 
 ✅ Parses actual brctl status output
 ✅ Detects uploading files (up:needs-upload)
 ✅ Detects downloading files (> downloader{...})
 ✅ Extracts file sizes and calculates GB pending
 ✅ Shows active folders (from "Under /path" lines)
 ✅ Dynamic icon animation when syncing
 ✅ Detailed logging to Console for debugging
 
 To debug:
 1. Run the app
 2. Open Console.app (or Xcode console)
 3. Look for "=== brctl status output ===" logs
 4. Check parsed values below each log
 
 The app updates every 5 seconds by running `brctl status`.
 */
