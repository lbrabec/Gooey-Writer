//
//  Writer.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 06.06.2024.
//

import Foundation
import AuthOpenWrapper


func unmountDisk(device: String) throws {
    let unmountProc = Process()
    unmountProc.executableURL = URL(fileURLWithPath: "/usr/sbin/diskUtil")
    unmountProc.arguments = ["unmountDisk", "force", device]
    try unmountProc.run()
    unmountProc.waitUntilExit()
}


func writeToDevice(device: String, imagePath: String, progressUpdater: (Double) -> ()) {
    let BLOCK_SIZE = 1024*1024
    var bytesWritten = 0

    guard let imageFileHandle = FileHandle(forReadingAtPath: imagePath) else {
        NSLog("Unable to upen file " + imagePath)
        return
    }

    do {
        try unmountDisk(device: device)

        let fd = OpenPathForReadWriteUsingAuthopen("/dev/r" + device)

        if(fd == -1) {
            NSLog("Horrible error")
            return
        }

        let deviceFileHandle = FileHandle(fileDescriptor: fd)

        let imageByteCount = try imageFileHandle.seekToEnd()
        NSLog("Image size: \(imageByteCount) bytes")
        try imageFileHandle.seek(toOffset: 0)

        while bytesWritten < imageByteCount {
            try autoreleasepool {
                guard let data = try imageFileHandle.read(upToCount: BLOCK_SIZE) else {
                    return
                }
                deviceFileHandle.write(data)
                bytesWritten = bytesWritten + data.count
                let progress = Double(bytesWritten) / Double(imageByteCount)
                progressUpdater(progress)
                print(100.0 * progress)
            }
        }
        NSLog("Total bytes written: \(bytesWritten)")
        try deviceFileHandle.synchronize()
        try deviceFileHandle.close()

        try unmountDisk(device: device)
    }
    catch {
        NSLog("Some crazy error in writeToDevice")
    }
}
