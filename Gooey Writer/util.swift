//
//  util.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 11.06.2024.
//

import Foundation
import Citadel
import OrderedCollections
import Virtualization

let MAC_ADDRESS = VZMACAddress.randomLocallyAdministered().string

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()
    
    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    task.launch()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!
    
    return output
}

class _SSH {
    var client: SSHClient? = nil
    
    func connect(ip: String, user: String, password: String) async throws {
        self.client = try await SSHClient.connect(
            host: ip,
            port: 22,
            authenticationMethod: .passwordBased(username: user, password: password),
            hostKeyValidator: .acceptAnything(), // Please use another validator if at all possible, it's insecure
            reconnect: .never
        )
    }
    
    func command(_ cmd: String) async throws -> String {
        let buffer = try await self.client!.executeCommand(cmd, mergeStreams: true, inShell: true)
        let result = buffer.getString(at: 0, length: buffer.readableBytes, encoding: .utf8)!
        return result
    }
    
    func c(_ cmd: String) async throws {
        let streamOutput = try await self.client!.executeCommandStream(cmd, inShell: true)
        for try await blob in streamOutput {
            switch blob {
            case let .stdout(stdout):
                print(String(buffer: stdout))
            case let .stderr(stderr):
                print(String(buffer: stderr))
            }
        }
    }
}

let SSH = _SSH()

func armInstallerCommand(_ target: String,
                         _ noRootPass: Bool,
                         _ showBoot: Bool,
                         _ useArgs: Bool,
                         _ args: String,
                         _ useKey: Bool,
                         _ sysConsole: Bool,
                         _ relabel: Bool,
                         _ sysrq: Bool) -> String {
    var command = [
        "arm-image-installer",
        "--media=/dev/vdb",
        "-y",
    ]
    if target != "none" {
        command.append("--target=" + target)
    }
    if noRootPass {
        command.append("--norootpass")
    }
    if showBoot {
        command.append("--showboot")
    }
    if useArgs {
        command.append("--args \"\(args)\"")
    }
    if useKey {
        command.append("--addkey /root/id.pub")
    }
    if sysConsole {
        command.append("--addconsole")
    }
    if relabel {
        command.append("--relabel")
    }
    if sysrq {
        command.append("--sysrq")
    }
    /*
         --resizefs      - Resize root filesystem to fill media device
     */
    
    return command.joined(separator: " ")
}

func sizeToPretty(size: Int64) -> String {
    if size == 0 {
        return "unknown GB"
    }
    
    let dSize = Double(size)
    
    var sizeStr: String;
    if (size < (1000)) {
        sizeStr = String(format: "%d B", size)
    } else if (size < (1000000)) {
        sizeStr = String(format: "%.1f KB", dSize / 1000.0)
    } else if (size < (1000000000)) {
        sizeStr = String(format: "%.1f MB", dSize / 1000000.0)
    } else if (size < (1000000000000)) {
        sizeStr = String(format: "%.1f GB", dSize / 1000000000.0)
    } else if (size < (1000000000000000)) {
        sizeStr = String(format: "%.1f TB", dSize / 1000000000000.0)
    } else {
        sizeStr = String(format: "%.1f EB", dSize / 1000000000000000.0)
    }
    return sizeStr;
}

func supportedBoards() -> OrderedDictionary<String, String> {
    return [
        "none": "No target board",
        "rpi3": "Raspberry Pi 3",
        "rpi4": "Raspberry Pi 4",
    ]
}
