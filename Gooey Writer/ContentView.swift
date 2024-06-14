//
//  ContentView.swift
//  Gooey Writer
//
//  Created by Lukas Brabec on 05.06.2024.
//

import SwiftUI
import OrderedCollections
import UniformTypeIdentifiers


struct ChooseDriveView: View {
    @Binding var selectedDrive : String
    @Binding var drives : OrderedDictionary<String, String>
    
    var body: some View {
        HStack {
            Label("Choose drive", systemImage: "sdcard.fill")
            Spacer()
            Picker("", selection: $selectedDrive) {
                ForEach(drives.elements, id: \.key) { element in
                    Text(element.value).tag(element.key)
                }
            }.frame(width: 300)
        }
    }
}

struct ChooseImageView: View {
    @State private var isImporting: Bool = false
    @Binding var selectedImage: URL?
    
    var body: some View {
        VStack {
            HStack {
                Label("Chosen image to alter and burn", systemImage: "doc.circle.fill")
                Spacer()
                Button(action: {
                    isImporting = true
                }, label: {
                    Text("Browse...")
                })
                .fileImporter(isPresented: $isImporting,
                              allowedContentTypes: [.rawImage, .diskImage],
                              onCompletion: { result in
                    
                    switch result {
                        case .success(let url):
                            // url contains the URL of the chosen file.
                            NSLog(url.absoluteString)
                            self.selectedImage = url
                        case .failure(let error):
                            NSLog(error.localizedDescription)
                    }
                })
            }
            HStack {
                Spacer()
                if selectedImage == nil {
                    Text("No image chosen").foregroundStyle(.gray)
                } else {
                    Text(selectedImage!.lastPathComponent)
                }
            }
        }
    }
}

struct OptionsView: View {
    @Binding var targetBoard: String
    @Binding var boards: OrderedDictionary<String, String>
    @Binding var noRootPass: Bool
    @Binding var showBoot: Bool
    @Binding var useArgs: Bool
    @Binding var args: String
    @Binding var useKey: Bool
    @Binding var pubKeyURL: URL?
    @Binding var sysConsole: Bool
    @Binding var relabel: Bool
    @Binding var sysrq: Bool
    
    @State private var isImporting: Bool = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Toggle(isOn: $noRootPass) {
                    Text("Disable root password")
                }
                Toggle(isOn: $showBoot) {
                    Text("Show boot messages (removes 'rhgb quiet')")
                }
                Toggle(isOn: $sysConsole) {
                    Text("Add system console for the target")
                }
                Spacer()
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading) {
                Toggle(isOn: $relabel) {
                    Text("SELinux relabel root filesystem on first boot")
                }
                Toggle(isOn: $sysrq) {
                    Text("System Request debugging of the kernel")
                }
                Toggle(isOn: $useArgs) {
                    Text("Additional kernel parameters")
                }
                HStack {
                    Spacer()
                    TextField(
                            "kernel args",
                            text: $args
                    ).frame(width: 293).textFieldStyle(.roundedBorder).disabled(!useArgs)
                }
                
                Spacer()
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        
        VStack(alignment: .leading){
            HStack {
                Toggle(isOn: $useKey) {
                    Text("Copy SSH public key to image")
                }
                Spacer()
                Button(action: {
                    isImporting = true
                }, label: {
                    Text("Browse...")
                })
                .fileImporter(isPresented: $isImporting,
                              allowedContentTypes: [.data],
                              onCompletion: { result in
                    
                    switch result {
                        case .success(let url):
                            NSLog(url.absoluteString)
                            pubKeyURL = url
                        case .failure(let error):
                            NSLog(error.localizedDescription)
                    }
                }).disabled(!useKey)
            }
            HStack {
                Spacer()
                Text(pubKeyURL?.path() ?? "None").foregroundStyle(useKey ? .black : .gray )
            }
            
            HStack {
                Label("Target board", systemImage: "cpu.fill")
                Spacer()
                Picker("", selection: $targetBoard) {
                    ForEach(boards.elements, id: \.key) { element in
                        Text(element.value).tag(element.key)
                    }
                }.frame(width: 300)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ContentView: View {
    @Binding var drives: OrderedDictionary<String, String>
    var onDiskAppeared : (DADisk) -> ()
    var onDiskDisappeared : (DADisk) -> ()
    
    @State private var progress = 0.0
    @State private var selectedDrive = "none"
    @State private var isImporting: Bool = false
    @State private var selectedImage: URL? = nil
    @State private var targetBoard: String = "none"
    @State private var boards: OrderedDictionary = supportedBoards()
    @State private var args: String = "nomodeset"
    @State private var noRootPass: Bool = false
    @State private var showBoot: Bool = false
    @State private var useArgs: Bool = false
    @State private var useKey: Bool = false
    @State private var pubKeyURL: URL? = FileManager.default.fileExists(atPath: NSHomeDirectory() + "/.ssh/id_rsa.pub") ? URL(filePath: NSHomeDirectory() + "/.ssh/id_rsa.pub") : nil
    @State private var sysConsole: Bool = false
    @State private var relabel: Bool = false
    @State private var sysrq: Bool = false
    
    @State private var ip: String = ""
    
    @State private var VMMagicRunning: Bool = false
    @State private var VMMagicState: String = "off"
    @State private var VMMagicStateMap = ["off": 0.0, "boot": 0.25, "ssh": 0.75, "finished": 1.0]

    func progressUpdater(progressValue: Double) {
        progress = progressValue
    }
    
    func burnImage() {
        if selectedDrive != "none" {
            NSLog("Writing \(selectedImage!.absoluteURL) to /disk/r\(selectedDrive)")
            print(self.selectedDrive)
            DispatchQueue.global().async {
                writeToDevice(device: self.selectedDrive,
                              imagePath: self.selectedImage!.path,
                              progressUpdater: progressUpdater)
            }
        }
    }
    
    func sendSSHCommand() {
        Task {
            do {
                VMMagicState = "ssh"
                NSLog("Connecting to VM with IP address: " + ip)
                try await SSH.connect(ip: ip, user: "root", password: Config.password)
                if useKey {
                    NSLog("Copying SSH public key to VM")
                    do {
                        let pubKey = try String(contentsOf: pubKeyURL!, encoding: .utf8)
                        try await SSH.c("echo \"\(pubKey)\" > ~/id.pub")
                    } catch {
                        NSLog("Copying SSH public key failed")
                        useKey = false // FIXME handle this better
                    }

                }
                
                let cmd = armInstallerCommand(targetBoard,
                                              noRootPass,
                                              showBoot,
                                              useArgs,
                                              args,
                                              useKey,
                                              sysConsole,
                                              relabel,
                                              sysrq)
                NSLog("Executing command in VM: " + cmd)
                try await SSH.c(cmd)
                //try await SSH.c("shutdown -h now")
                NSLog("Finished work in VM")
                VMMagicRunning = false
                try await SSH.client?.close()
                VMMagicState = "finished"
            } catch {
                NSLog("Error in working with VM")
            }
        }
    }
    
    func doVMMagic(){
        if selectedImage == nil {
            return
        }
        
        VMMagicRunning = true
        if ip == "" {
            runVM(selectedImage!)
            VMMagicState = "boot"
            NSLog("VM MAC is: " + MAC_ADDRESS)
            let timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { timer in
                let out = shell("arp -a | grep -i '\(MAC_ADDRESS)' | cut -d '(' -f2 | cut -d ')' -f1")
                NSLog("Waiting for VM IP")
                if out != "" { //FIXME better check... regex?
                    timer.invalidate()
                    ip = out.trimmingCharacters(in: .whitespacesAndNewlines)
                    NSLog("VM IP is: " + ip)
                    sendSSHCommand()
                }
            }
            timer.tolerance = 1.0
            DispatchQueue.global().asyncAfter(deadline: .now() + 4.0) {
                timer.fire()
            }
            //}
        } else {
            sendSSHCommand()
        }
        
    }
    
    var body: some View {
        VStack {
            ChooseImageView(selectedImage: $selectedImage)
            ChooseDriveView(selectedDrive: $selectedDrive, drives: $drives)
            
            Divider()

            OptionsView(targetBoard: $targetBoard,
                        boards: $boards,
                        noRootPass: $noRootPass,
                        showBoot: $showBoot,
                        useArgs: $useArgs,
                        args: $args,
                        useKey: $useKey,
                        pubKeyURL: $pubKeyURL,
                        sysConsole: $sysConsole,
                        relabel: $relabel,
                        sysrq: $sysrq)
            HStack {
                Spacer()
                Button(action: doVMMagic) {
                    Label("Apply", systemImage: "arrowshape.down.circle.fill")
                }.disabled(selectedImage == nil)
            }
            ProgressView(value: VMMagicStateMap[VMMagicState]) { } currentValueLabel: {
                switch VMMagicState {
                case "boot":
                        Text("Waiting for VM to boot")
                case "ssh":
                        Text("Altering image")
                case "finished":
                        Text("Image altered")
                default:
                        Text("VM is off")
                }
            }.animation(.easeInOut, value: VMMagicStateMap[VMMagicState])

            Divider()
            Spacer()
            if progress == 0.0 {
                ProgressView(value: progress) {
                    HStack {
                        Label("Click Burn to start burning", systemImage: "flame.circle.fill")
                        Spacer()
                        Button(action: burnImage) {
                            Label("Burn", systemImage: "arrowshape.down.circle.fill")
                        }.disabled(selectedImage == nil || selectedDrive == "none")
                    }
                    
                    
                } currentValueLabel: {
                    Text("not yet started")
                }
            } else
            if progress == 1.0 {
                ProgressView(value: progress) {
                    HStack {
                        Text("Burning done")
                        Spacer()
                        Button(action: {progress = 0.0; selectedDrive = "none"}) {
                            Label("Another", systemImage: "arrowshape.turn.up.backward.circle.fill")
                        }
                    }
                } currentValueLabel: {
                    Text("Finished")
                }
            } else {
                ProgressView(value: progress) {
                    Text("Burning progress")
                } currentValueLabel: {
                    Text("\(Int(100*progress)) %")
                }
            }
            
        }
        .frame(width: 600, height: 390)
        .padding()
        .onAppear {
            startArbiter(onDiskAppearedCB: onDiskAppeared, onDiskDisappearedCB: onDiskDisappeared)
        }
    }
}

struct ContentViewPreviewWrapper: View {
    @State var drives: OrderedDictionary<String, String> = ["none": "none"] // FIXME wtf @State ??
    
    func onDiskAppeared(disk: DADisk) {
        let bsdname = getBSDName(disk: disk)
        let prettyname = getPrettyName(disk: disk)
        drives[bsdname!] = prettyname
    }
    
    func onDiskDisappered(disk: DADisk) {
        let bsdname = getBSDName(disk: disk)
        drives.removeValue(forKey: bsdname!)
    }
    
    var body: some View {
        ContentView(drives: $drives, onDiskAppeared: onDiskAppeared, onDiskDisappeared: onDiskDisappered)
    }
}

#Preview {
    ContentViewPreviewWrapper()
}
