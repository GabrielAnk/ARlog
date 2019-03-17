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
    let serverURL = ""                              // URL of the server endpoint
    let projectID = ""                              // projectID of the AR project, where it is saved on the server
    
    
    // functions
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
        
            let sessionUrl = URL(string: serverURL + "/log/" + projectID + "/" + sessionName)
        
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
//                AFuploader(zipfileURL!, sessionUrl!)
                UrlUploader(zipfileURL!, sessionUrl!)
            }
            else if (largeOnlyWifi == false){
                //                AFuploader(zipfileURL!, sessionUrl!)
                UrlUploader(zipfileURL!, sessionUrl!)
            }
            else if (isLargeFile(zipfileURL!) == true && largeOnlyWifi == true && isWifi() == true){
                //                AFuploader(zipfileURL!, sessionUrl!)
                UrlUploader(zipfileURL!, sessionUrl!)
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
    
    func UrlUploader(_ zipfileURL: URL,_ sessionUrl: URL){
        var request = URLRequest(url: sessionUrl)
        request.httpMethod = "POST"
        let config = URLSessionConfiguration.background(withIdentifier: zipfileURL.lastPathComponent)
        let session = URLSession(configuration: config)
        print(request)
        let task = session.uploadTask(with: request, fromFile: zipfileURL)
        task.resume()
    }
    
//    func AFuploader(_ zipfileURL: URL,_ sessionUrl: URL){
//        AF.upload(
//            multipartFormData: { multipartFormData in
//                multipartFormData.append(zipfileURL, withName: "file")
//        },
//            to: sessionUrl, method: .post
//            ).responseString { response in
//                debugPrint(response)
//        }
//    }
    
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

#endif
