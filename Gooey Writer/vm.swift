//
//  vm.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 11.06.2024.
//

import Foundation
import Virtualization

class Delegate: NSObject {
}

extension Delegate: VZVirtualMachineDelegate {
    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        NSLog("The guest shut down. Exiting.")
        exit(EXIT_SUCCESS)
    }
    
    func virtualMachine(_ : VZVirtualMachine, didStopWithError: any Error) {
        NSLog("Some VM error")
    }
    
    func virtualMachine(_ : VZVirtualMachine, networkDevice: VZNetworkDevice, attachmentWasDisconnectedWithError: any Error) {
        NSLog("Some VM network error")
    }
}


var globVM: VZVirtualMachine? = nil

func runVM(_ burnImageURL: URL) {
    func createStorageDevice(url: URL) -> VZVirtioBlockDeviceConfiguration {
        let blockAttachment: VZDiskImageStorageDeviceAttachment
        do {
            blockAttachment = try VZDiskImageStorageDeviceAttachment(
                url: url,
                readOnly: false
            )
        } catch {
            NSLog("Failed to load bootableImage: \(error)")
            exit(EXIT_FAILURE)
        }
        return VZVirtioBlockDeviceConfiguration(attachment: blockAttachment)
    }
    
    func createNetworkDevice() -> VZVirtioNetworkDeviceConfiguration {
        let networkDevice = VZVirtioNetworkDeviceConfiguration()
        networkDevice.macAddress = VZMACAddress(string: MAC_ADDRESS)!
        networkDevice.attachment = VZNATNetworkDeviceAttachment()
        return networkDevice
    }
    
    func createBootLoader() -> VZBootLoader {
        if !FileManager.default.fileExists(atPath: Config.efiVariableStoreURL().path()) {
            guard let efiVariableStore = try? VZEFIVariableStore(creatingVariableStoreAt: Config.efiVariableStoreURL()) else {
                fatalError("Failed to create the EFI variable store.")
            }
            let bootloader = VZEFIBootLoader()
            bootloader.variableStore = efiVariableStore
            return bootloader
        } else {
            let bl = VZEFIBootLoader()
            bl.variableStore = VZEFIVariableStore(url: Config.efiVariableStoreURL())
            return bl
        }
    }
    
    DispatchQueue.main.async {
        let configuration = VZVirtualMachineConfiguration()
        configuration.cpuCount = 4
        configuration.memorySize = 2 * 1024 * 1024 * 1024 // 2 GiB
        configuration.bootLoader = createBootLoader()
        configuration.entropyDevices = [ VZVirtioEntropyDeviceConfiguration() ]
        configuration.memoryBalloonDevices = [ VZVirtioTraditionalMemoryBalloonDeviceConfiguration() ]
        configuration.storageDevices = [ createStorageDevice(url: Config.bootableImageURL), 
                                         createStorageDevice(url: burnImageURL) ]
        configuration.networkDevices = [ createNetworkDevice() ]
        
        do {
            NSLog("Validating the virtual machine configuration.")
            try configuration.validate()
        } catch {
            NSLog("Failed to validate the virtual machine configuration. \(error)")
            exit(EXIT_FAILURE)
        }
        
        globVM = VZVirtualMachine(configuration: configuration)
        
        let delegate = Delegate()
        globVM!.delegate = delegate
        
        NSLog("Starting the virtual machine")
        
        globVM!.start { (result) in
            switch result {
            case .success:
                NSLog("Virtual machine started successfuly.")
            case .failure(let error):
                NSLog("Failed to start the virtual machine. \(error)")
                exit(EXIT_FAILURE)
            }
        }
    }
    
}
