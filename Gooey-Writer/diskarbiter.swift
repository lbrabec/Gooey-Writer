//
//  diskarbiter.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 06.06.2024.
//

import Foundation
import CoreFoundation
import DiskArbitration

var _onDiskAppeared : (DADisk) -> () = {_ in print("placeholder")}
var _onDiskDisappeared : (DADisk) -> () = {_ in print("placeholder")}

let session = DASessionCreate(kCFAllocatorDefault)!

func diskAppeared(disk: DADisk, context: UnsafeMutableRawPointer?) {
    let diskDescription = DADiskCopyDescription(disk) as? [NSString: Any]
    
    let isInternal = diskDescription?[kDADiskDescriptionDeviceInternalKey] as? Bool
    let bsdname = diskDescription?[kDADiskDescriptionMediaBSDNameKey] as? String
    // for some reason, sometimes USB flash drive connected to monitor or hub is
    // not recognized as removable
    let isRemovable = diskDescription?[kDADiskDescriptionMediaRemovableKey] as? Bool
    let isWhole = diskDescription?[kDADiskDescriptionMediaWholeKey] as? Bool
    
    let isInternalSDCardReader = (isInternal ?? false) && (isRemovable ?? false)
    
    NSLog("Some disk appeared")
    if bsdname != nil && isInternal != nil {
        if (!isInternal! || isInternalSDCardReader) && isWhole! {
            NSLog("Non-internal whole device /dev/" + bsdname!)
            _onDiskAppeared(disk)
        }
    }
}

func diskDisappeared(disk: DADisk, context: UnsafeMutableRawPointer?) {
    let diskDescription = DADiskCopyDescription(disk) as? [NSString: Any]
    
    let isInternal = diskDescription?[kDADiskDescriptionDeviceInternalKey] as? Bool
    let isWhole = diskDescription?[kDADiskDescriptionMediaWholeKey] as? Bool
    
    if !isInternal! && isWhole! {
        _onDiskDisappeared(disk)
    }
}

func getBSDName(disk: DADisk) -> String? {
    let diskDescription = DADiskCopyDescription(disk) as? [NSString: Any]
    return diskDescription?[kDADiskDescriptionMediaBSDNameKey] as? String
}

func getPrettyName(disk: DADisk) -> String? {
    let diskDescription = DADiskCopyDescription(disk) as? [NSString: Any]
    let diskSize = diskDescription?[kDADiskDescriptionMediaSizeKey] as? Int64
    let diskVendor = diskDescription?[kDADiskDescriptionDeviceVendorKey] as? String
    let diskModel = diskDescription?[kDADiskDescriptionDeviceModelKey] as? String
    
    //print("vendor: ", diskVendor ?? "Unknown", "model: ", diskModel ?? "Unknown", "size: ", diskSize ?? "no size")
    
    return (diskVendor ?? "Unknown") + " " + (diskModel ?? "unknown") + " (" + sizeToPretty(size: diskSize ?? 0) + ")"
}

func startArbiter(onDiskAppearedCB : @escaping (DADisk) -> (), onDiskDisappearedCB : @escaping (DADisk) -> ()) {
    NSLog("Starting disk arbiter")
    
    _onDiskAppeared = onDiskAppearedCB
    _onDiskDisappeared = onDiskDisappearedCB
    
    DARegisterDiskAppearedCallback(session, nil, diskAppeared, nil)
    DARegisterDiskDisappearedCallback(session, nil, diskDisappeared, nil)
    
    DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
}

class _DiskArbiter {
    private let session = DASessionCreate(kCFAllocatorDefault)!
    private var onDiskAppeared_External : (DADisk) -> () = {_ in NSLog("Appeared placeholder")}
    private var onDiskDisappeared_External : (DADisk) -> () = {_ in NSLog("Disappeared placeholder")}
    
    func start(onDiskAppearedCB : @escaping (DADisk) -> (), onDiskDisappearedCB : @escaping (DADisk) -> ()) {
        NSLog("Starting disk arbiter")
        
        self.onDiskAppeared_External = onDiskAppearedCB
        self.onDiskDisappeared_External = onDiskDisappearedCB
        
        DARegisterDiskAppearedCallback(session, nil, diskAppeared, nil)
        DARegisterDiskDisappearedCallback(session, nil, diskDisappeared, nil)
        
        DASessionScheduleWithRunLoop(session, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
}

let DiskArbiter = _DiskArbiter()
