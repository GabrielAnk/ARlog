//
//  ARlogUpload.swift
//  ARlog
//
//  Created by Gabriel Ankeshian on 22.02.19. Contact: gabriel.ankeshian@gmail.com
//


#if DEBUG

import Foundation               // includes URLSession
import SystemConfiguration
import ZIPFoundation
import Connectivity             // needed to detect if wifi or cellular connection

public class ARlogUpload{

    // User Flags
    let doUpload = true                             // if this is true ARlog will try to upload
    let onlyWifi = false                            // if this is true it will only upload when wifi is available
    let largeOnlyWifi = false                       // if this is true large files will only be uploaded when wifi is connected
    let serverURL = "https://service.metason.net/arlog"                // URL of the server endpoint "http://<ip>:<port>"
    let projectID = ""                              // projectID of the AR project, where it is saved on the server
    
    
    // upload functionality
    func upload(_ sessionFilesUrl: String,_ sessionName: String){
        var dynUpload = doUpload
                
        if (isWifi() == true && onlyWifi == true){
            dynUpload = true
        }
        if (isWifi() == false && onlyWifi == true){
            dynUpload = false
        }
        if (largeOnlyWifi == true && isWifi() == true){
            dynUpload = true
        }
        if (largeOnlyWifi == true && isWifi() == false){
            dynUpload = false
        }
        
        if (doUpload == true && dynUpload == true && isConnection() == true){
        
            let uploadUrl = URL(string: serverURL + "/log/" + projectID + "/" + sessionName)
        
            let filePathString = sessionFilesUrl + sessionName + ".zip"
            let zipfileURL = URL(string: filePathString)
        
            let zipPath = URL(string: sessionFilesUrl)
            let filemngr = FileManager()
        
            do {
                try filemngr.zipItem(at: zipPath!, to:zipfileURL!)
            } catch {
                print("Creation of ZIP archive failed with error:\(error)")
            }
        
            if (isLargeFile(zipfileURL!) == false){
                singleFileUploader(sessionFilesUrl, uploadUrl!)
            }
            else if (largeOnlyWifi == false){
                singleFileUploader(sessionFilesUrl, uploadUrl!)
            }
            else if (isLargeFile(zipfileURL!) == true && largeOnlyWifi == true && isWifi() == true){
                singleFileUploader(sessionFilesUrl, uploadUrl!)
            }
            else{
                print("file is too large with no wifi ")
            }
            
        }
        else if (doUpload == false){
            print("Uploads are disabled.")
        }
        else if (dynUpload == false){
            print("no upload possible. something conflicts with your flags, is your wifi on?")
        }
        else{
            print("something is going wrong")
        }
        
    }

    // uploads all the files belonging to a session
    func singleFileUploader(_ sessionFilesUrl: String,_ uploadUrl: URL){
        let sessionJsonFile = URL(string: sessionFilesUrl + "session.json")
        let videoFile = URL(string: sessionFilesUrl + "screen.mp4")
        let mapsFolder = URL(string: sessionFilesUrl + "maps/")
        let scenesFolder = URL(string: sessionFilesUrl + "scenes/")
        
        // upload the session files in the session directory
        fileUpload(sessionJsonFile!, uploadUrl, "session", "application/json", "session.json")
        fileUpload(videoFile!, uploadUrl, "session", "video/mp4", "video.mp4")

        
        // loop through the folders of the session directory to upload each file
        // https://stackoverflow.com/a/47761434
        let fm = FileManager()
        do {
            if dirExists(scenesFolder!.path){
            let fileURLs = try fm.contentsOfDirectory(at: scenesFolder!, includingPropertiesForKeys: nil)

            for fileUrl in fileURLs{
                fileUpload(fileUrl, uploadUrl, "scenes", "scene", fileUrl.lastPathComponent)
                }
            }
            else {print("scenes folder does not exists")}

            if dirExists(mapsFolder!.path){
                let fileURLs = try fm.contentsOfDirectory(at: mapsFolder!, includingPropertiesForKeys: nil)

                for fileUrl in fileURLs{
                    fileUpload(fileUrl, uploadUrl, "maps", "application/json", fileUrl.lastPathComponent)
                }
            }
            else {print("maps folder does not exists")}

        } catch {
            print("Error while enumerating files: \(error.localizedDescription)")
        }
    }
    
    func fileUpload(_ uploadFile: URL, _ uploadUrl: URL, _ subfolder: String, _ contentType: String,_ filename: String){
        var request = URLRequest(url: uploadUrl)
        request.httpMethod = "POST"
        request.setValue(subfolder, forHTTPHeaderField: "X-Session-Subfolder")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(filename, forHTTPHeaderField: "X-Filename")
        let config = URLSessionConfiguration.background(withIdentifier: UUID().uuidString)
        let session = URLSession(configuration: config)
        print(request)
        
        let task = session.uploadTask(with: request, fromFile: uploadFile)
        task.resume()
    }

    func isLargeFile(_ zipfileURL: URL) -> Bool{
        // if a file is larger than 100mb this function will return true
        let fileSize = zipfileURL.fileSize;
        if (fileSize >= 104857600){
            return true
        }
        else{
            return false
        }
    }
    
    func dirExists(_ fullPath: String) -> Bool{
        // https://stackoverflow.com/a/24696209
        let fileManager = FileManager.default
        var isDir : ObjCBool = false
        if fileManager.fileExists(atPath: fullPath, isDirectory:&isDir) {
            if isDir.boolValue {
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }
    
    
//    network helper functions
//    https://github.com/rwbutler/Connectivity
    
    
    func isWifi() -> Bool {
        let connectivity = Connectivity()
        return (connectivity.isConnectedViaWiFi || connectivity.isConnectedViaWiFiWithoutInternet)
    }

    func isCellular() -> Bool{
        let connectivity = Connectivity()
        return (connectivity.isConnectedViaCellular || connectivity.isConnectedViaCellularWithoutInternet)
    }

    func isConnection() -> Bool{
        return (isWifi() || isCellular())
    }

    //    TODO: move to a native framework for connectivity
//    func isConnection() -> Bool{
//        if Reachability.isConnectedToNetwork(){
//            return true;
//        } else {
//            return false
//        }
//    }
}



extension URL {
    // https://stackoverflow.com/a/48566887
    var attributes: [FileAttributeKey : Any]? {
        do {
            return try FileManager.default.attributesOfItem(atPath: path)
        } catch let error as NSError {
            print("FileAttribute error: \(error)")
        }
        return nil
    }
    
    var fileSize: UInt64 {
        return attributes?[.size] as? UInt64 ?? UInt64(0)
    }
    
    var fileSizeString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var creationDate: Date? {
        return attributes?[.creationDate] as? Date
    }
}

//    TODO: move to a native framework for connectivity
//public class Reachability {
//    // https://stackoverflow.com/a/39782859
//
//    class func isConnectedToNetwork() -> Bool {
//
//        var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
//        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
//        zeroAddress.sin_family = sa_family_t(AF_INET)
//
//        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
//            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
//                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
//            }
//        }
//
//        var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
//        if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
//            return false
//        }
//
//        /* Only Working for WIFI
//         let isReachable = flags == .reachable
//         let needsConnection = flags == .connectionRequired
//
//         return isReachable && !needsConnection
//         */
//
//        // Working for Cellular and WIFI
//        let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
//        let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
//        let ret = (isReachable && !needsConnection)
//
//        return ret
//
//    }
//}
#endif
