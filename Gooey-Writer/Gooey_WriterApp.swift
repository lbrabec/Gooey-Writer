//
//  Gooey_WriterApp.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 14.06.2024.
//

import Foundation
import AppKit
import SwiftUI
import OrderedCollections

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

@main
struct app_testApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @State var drives: OrderedDictionary<String, String> = ["none": "No drive selected"]
    
    
    init() {
        Config.ensureConfigPathExists()
    }
    
    func onDiskAppeared(disk: DADisk) {
        let bsdname = getBSDName(disk: disk)
        let prettyname = getPrettyName(disk: disk)
        drives[bsdname!] = prettyname
    }
    
    func onDiskDisappeared(disk: DADisk) {
        let bsdname = getBSDName(disk: disk)
        drives.removeValue(forKey: bsdname!)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(drives: $drives, onDiskAppeared: onDiskAppeared, onDiskDisappeared: onDiskDisappeared)
        }
    }
}
