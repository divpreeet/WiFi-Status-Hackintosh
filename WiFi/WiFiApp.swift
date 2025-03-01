import SwiftUI
import AppKit

@main
struct Wifi: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var isConnected: Bool = false
    var currentSSID: String = "Unknown"
    var ipAddress: String = ""
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatusIcon()
        statusItem?.menu = createMenu()
        updateWiFiStatus()
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        var statusTitle = ""
        if isConnected {
            statusTitle = "Connected: \(currentSSID)"
            if !ipAddress.isEmpty {
                statusTitle += " (\(ipAddress))"
            }
        } else {
            statusTitle = "Disconnected"
        }
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        let toggleTitle = isConnected ? "Reconnect WiFi" : "Connect WiFi"
        menu.addItem(NSMenuItem(title: toggleTitle, action: #selector(toggleWiFi), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Refresh Status", action: #selector(updateWiFiStatus), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }
    
    func updateStatusIcon() {
        DispatchQueue.main.async {
            let imageName = self.isConnected ? "wifi" : "wifi.slash"
            self.statusItem?.button?.image = NSImage(systemSymbolName: imageName, accessibilityDescription: "WiFi")
        }
    }
    
    func getLastNetwork() -> String {
        let plistPath = "/Library/Application Support/WLAN/com.realtek.utility.wifi/wifiUtility.plist"
        guard let data = FileManager.default.contents(atPath: plistPath) else {
            print("Failed to read plist at \(plistPath)")
            return "Unknown"
        }
        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let lastNetwork = plist["Last Network"] as? String {
                return lastNetwork
            }
        } catch {
            print("Failed to parse wifiUtility.plist: \(error)")
        }
        return "Unknown"
    }
    
    func getIPAddress() -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/sbin/ifconfig")
        process.arguments = ["en1"]
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("Failed to run ifconfig: \(error)")
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return "" }
        for line in output.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("inet ") {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ")
                if parts.count > 1 {
                    return parts[1]
                }
            }
        }
        return ""
    }
    
    @objc func updateWiFiStatus() {
        currentSSID = getLastNetwork()
        ipAddress = getIPAddress()

        isConnected = !ipAddress.isEmpty
        updateStatusIcon()
        statusItem?.menu = createMenu()
    }
    
    @objc func toggleWiFi() {
        connectWiFi()
    }
    
    func connectWiFi() {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/Library/Application Support/WLAN/com.realtek.utility.wifi/RtWlanHelper")
            process.arguments = []
            process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Failed to connect WiFi: \(error)")
            }
            sleep(1)
            DispatchQueue.main.async {
                self.updateWiFiStatus()
                NSSound(named: "Ping")?.play()
            }
        }
    }
}
