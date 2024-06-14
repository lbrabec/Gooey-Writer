//
//  config.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 12.06.2024.
//

import Foundation



class _Config {
    let gooeyWriterBasePath = NSHomeDirectory() + "/.gooeywriter"
    
    var bootableImageURL = URL(fileURLWithPath: NSHomeDirectory() + "/Downloads/fedora40/storage-old.img")
    var password: String = "fedora"

    func ensureConfigPathExists() {
        if !FileManager.default.fileExists(atPath: self.gooeyWriterBasePath) {
            do {
                try FileManager.default.createDirectory(atPath: self.gooeyWriterBasePath, withIntermediateDirectories: true)
            } catch {
                fatalError("Failed to create \(self.gooeyWriterBasePath)")
            }
        }
    }
    
    func efiVariableStoreURL() -> URL {
        return URL(fileURLWithPath: self.gooeyWriterBasePath + "/NVRAM")
    }
    
    func isValid() -> Bool {
        return FileManager.default.fileExists(atPath: self.bootableImageURL.path)
    }
    
    
}

let Config = _Config()
