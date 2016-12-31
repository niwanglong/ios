//
//  DocumentPickerViewController.swift
//  Picker
//
//  Created by Marino Faggiana on 27/12/16.
//  Copyright © 2016 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

class DocumentPickerViewController: UIDocumentPickerExtensionViewController, CCNetworkingDelegate, OCNetworkingDelegate {
    
    // MARK: - Properties
    
    var provider : providerSession?
    
    var metadata : CCMetadata?
    var recordsTableMetadata : [TableMetadata]?
    var titleFolder : String?
    
    var activeAccount : String?
    var activeUrl : String?
    var activeUser : String?
    var activePassword : String?
    var activeUID : String?
    var activeAccessToken : String?
    var directoryUser : String?
    var typeCloud : String?
    var serverUrl : String?
    
    var localServerUrl : String?
    
    lazy var networkingOperationQueue : OperationQueue = {
        
        var queue = OperationQueue()
        queue.name = netQueueName
        queue.maxConcurrentOperationCount = 1
        
        return queue
    }()
    
    var hud : CCHud!
    
    // MARK: - IBOutlets
    
    @IBOutlet weak var tableView: UITableView!
    
    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        
        provider = providerSession.sharedInstance
        
        if let record = CCCoreData.getActiveAccount() {
            
            activeAccount = record.account!
            activePassword = record.password!
            activeUrl = record.url!
            activeUser = record.user!
            typeCloud = record.typeCloud!
            directoryUser = CCUtility.getDirectoryActiveUser(activeUser, activeUrl: activeUrl)
            
            if (localServerUrl == nil) {
            
                localServerUrl = CCUtility.getHomeServerUrlActiveUrl(activeUrl, typeCloud: typeCloud)
                
            } else {
                
                self.navigationItem.title = titleFolder
            }
            
        } else {
            
            // Close error no account return nil
            
            let deadlineTime = DispatchTime.now() + 0.1
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                
                let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: NSLocalizedString("_no_active_account_", comment: ""), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
                    self.dismissGrantingAccess(to: nil)
                })
                
                self.present(alert, animated: true, completion: nil)
            }

            return
        }
        
        //  MARK: - init Object
        CCNetworking.shared().settingDelegate(self)
        hud = CCHud.init(view: self.navigationController?.view)
        
        // COLOR_SEPARATOR_TABLE
        self.tableView.separatorColor = UIColor(colorLiteralRed: 153.0/255.0, green: 153.0/255.0, blue: 153.0/255.0, alpha: 0.2)
        
        readFolder()
    }
    
    //  MARK: - Read folder
    
    func readFolder() {
        
        let metadataNet = CCMetadataNet.init(account: activeAccount)!

        metadataNet.action = actionReadFolder
        metadataNet.serverUrl = self.localServerUrl
        metadataNet.selector = selectorReadFolder
        
        let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, withTypeCloud: typeCloud, oneByOne: true, activityIndicator: false)
        networkingOperationQueue.addOperation(ocNetworking)
        
        hud.visibleIndeterminateHud()
    }
    
    func readFolderFailure(_ metadataNet: CCMetadataNet!, message: String!, errorCode: Int) {
        
        hud.hideHud()
        
        let alert = UIAlertController(title: NSLocalizedString("_error_", comment: ""), message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("_ok_", comment: ""), style: .default) { action in
            self.dismissGrantingAccess(to: nil)
        })
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func readFolderSuccess(_ metadataNet: CCMetadataNet!, permissions: String!, rev: String!, metadatas: [Any]!) {
        
        // remove all record
        let predicate = NSPredicate(format: "(account == '\(activeAccount!)') AND (directoryID == '\(metadataNet.directoryID!)') AND ((session == NULL) OR (session == ''))")
        CCCoreData.deleteMetadata(with: predicate)
        
        for metadata in metadatas as! [CCMetadata] {
            
            // do not insert crypto file
            if CCUtility.isCryptoString(metadata.fileName) {
                continue
            }
            
            // plist + crypto = completed ?
            if CCUtility.isCryptoPlistString(metadata.fileName) && metadata.directory == false {
                
                var isCryptoComplete = false
                
                for completeMetadata in metadatas as! [CCMetadata] {
                    if completeMetadata.fileName == CCUtility.trasformedFileNamePlist(inCrypto: metadata.fileName) {
                        isCryptoComplete = true
                    }
                }

                if isCryptoComplete == false {
                    continue
                }
            }
            
            // Add record
            CCCoreData.add(metadata, activeAccount: activeAccount, activeUrl: activeUrl, typeCloud: typeCloud, context: nil)
        }
        
        // Get Datasource
        recordsTableMetadata = CCCoreData.getTableMetadata(with: NSPredicate(format: "(account == '\(activeAccount!)') AND (directoryID == '\(metadataNet.directoryID!)')"), fieldOrder: CCUtility.getOrderSettings(), ascending: CCUtility.getAscendingSettings()) as? [TableMetadata]
        
        tableView.reloadData()
        
        hud.hideHud()
    }
    
    //  MARK: - Download Thumbnail

    func downloadThumbnail(_ metadata : CCMetadata) {
    
        let metadataNet = CCMetadataNet.init(account: activeAccount)!
        
        metadataNet.action = actionDownloadThumbnail
        metadataNet.fileID = metadata.fileID
        
        //let fileName =
        
        
        


        metadataNet.fileNameLocal = metadata.fileID;
        metadataNet.fileNamePrint = metadata.fileNamePrint;
        metadataNet.options = "m";
        metadataNet.selector = selectorDownloadThumbnail;
        metadataNet.serverUrl = self.localServerUrl

        let ocNetworking : OCnetworking = OCnetworking.init(delegate: self, metadataNet: metadataNet, withUser: activeUser, withPassword: activePassword, withUrl: activeUrl, withTypeCloud: typeCloud, oneByOne: true, activityIndicator: false)
        networkingOperationQueue.addOperation(ocNetworking)
        
        hud.visibleIndeterminateHud()
    }
}

// MARK: - UITableViewDelegate

extension DocumentPickerViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
         return 60
    }
}

// MARK: - UITableViewDataSource

extension DocumentPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (recordsTableMetadata == nil) {
            return 0
        } else {
            return recordsTableMetadata!.count
        }
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! recordMetadataCell
        
        cell.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0)
        
        let recordTableMetadata = recordsTableMetadata?[(indexPath as NSIndexPath).row]
        let metadata = CCCoreData.insertEntity(in: recordTableMetadata)!
        
        // File Image View
        let filePath = directoryUser! + "/" + metadata.fileID + ".ico"
        
        if (FileManager.default.fileExists(atPath: filePath)) {
            
            cell.fileImageView.image = UIImage(contentsOfFile: filePath)
            
        } else {
            
            cell.fileImageView.image = UIImage(named: metadata.iconName!)
        }
        
        // File Name
        cell.FileName.text = metadata.fileNamePrint
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let recordTableMetadata = recordsTableMetadata?[(indexPath as NSIndexPath).row]
        
        let nextViewController = self.storyboard?.instantiateViewController(withIdentifier: "DocumentPickerViewController") as! DocumentPickerViewController
        
        nextViewController.localServerUrl = CCUtility.stringAppendServerUrl(localServerUrl!, addServerUrl: recordTableMetadata!.fileName)
        nextViewController.titleFolder = recordTableMetadata?.fileNamePrint
        
        self.navigationController?.pushViewController(nextViewController, animated: true)
        
    }
}

// MARK: - Class UITableViewCell

class recordMetadataCell: UITableViewCell {
    
    @IBOutlet weak var fileImageView: UIImageView!
    @IBOutlet weak var FileName : UILabel!
}

// MARK: - Class providerSession

class providerSession {
    
    class var sharedInstance : providerSession {
        
        struct Static {
            
            static let instance = providerSession()
        }
        
        return Static.instance
    }
    
    private init() {
    
        let dirGroup = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: capabilitiesGroups)
        let pathDB = dirGroup?.appendingPathComponent(appDatabase).appendingPathComponent("cryptocloud")
        
        MagicalRecord.setupCoreDataStackWithAutoMigratingSqliteStore(at: pathDB!)
        MagicalRecord.setLoggingLevel(MagicalRecordLoggingLevel.off)
    }
}
