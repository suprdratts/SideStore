//
//  Bundle+AltStore.swift
//  AltStore
//
//  Created by Riley Testut on 5/30/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation

public extension Bundle
{
    struct Info
    {
        public static let deviceID = "ALTDeviceID"
        public static let serverID = "ALTServerID"
        public static let certificateID = "ALTCertificateID"
        public static let appGroups = "ALTAppGroups"
        public static let altBundleID = "ALTBundleIdentifier"

        public static let orgbundleIdentifier =  "com.SideStore"
        public static var appbundleIdentifier : String {
            get {
                if Bundle.isBundledWithLiveContainer {
                    return "com.kdt.livecontainer"
                } else {
                    return orgbundleIdentifier + ".SideStore"
                }
            }
        }
        public static let devicePairingString = "ALTPairingFile"
        public static let urlTypes = "CFBundleURLTypes"
        public static let exportedUTIs = "UTExportedTypeDeclarations"
        public static let backgroundModes = "UIBackgroundModes"
        
        public static let untetherURL = "ALTFugu14UntetherURL"
        public static let untetherRequired = "ALTFugu14UntetherRequired"
        public static let untetherMinimumiOSVersion = "ALTFugu14UntetherMinimumVersion"
        public static let untetherMaximumiOSVersion = "ALTFugu14UntetherMaximumVersion"
    }
}

public extension Bundle
{
    var infoPlistURL: URL {
        let infoPlistURL = self.bundleURL.appendingPathComponent("Info.plist")
        return infoPlistURL
    }
    
    var provisioningProfileURL: URL {
        let provisioningProfileURL = self.bundleURL.appendingPathComponent("embedded.mobileprovision")
        return provisioningProfileURL
    }
    
    var certificateURL: URL {
        let certificateURL = self.bundleURL.appendingPathComponent("ALTCertificate.p12")
        return certificateURL
    }
    
    var altstorePlistURL: URL {
        let altstorePlistURL = self.bundleURL.appendingPathComponent("AltStore.plist")
        return altstorePlistURL
    }
}

public extension Bundle
{
    static var baseAltStoreAppGroupID = "group.com.SideStore.SideStore"
    static var isBundledWithLiveContainer = Bundle.main.bundleURL.lastPathComponent == "SideStoreApp.framework" || Bundle.main.bundleURL.lastPathComponent == "LiveWidgetExtension.appex"
    static var cachedAltStoreAppGroup: String? = nil

    var appGroups: [String] {
        return self.infoDictionary?[Bundle.Info.appGroups] as? [String] ?? []
    }
    
    static var lcBundle: Bundle? {
        return Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent())
    }
    
    static var realMainBundle: Bundle {
        (Bundle.isBundledWithLiveContainer ? Bundle.lcBundle ?? Bundle.main : Bundle.main)
    }
    
    var altstoreAppGroup: String? {
        if let cached = Bundle.cachedAltStoreAppGroup {
            return cached
        }
        if Bundle.isBundledWithLiveContainer, let lcBundle = Bundle.lcBundle {
            let ans = lcBundle.appGroups.first { $0.contains("group.com.SideStore.SideStore") }
            Bundle.cachedAltStoreAppGroup = ans
            return ans
        }
        let appGroup = self.appGroups.first { $0.contains(Bundle.baseAltStoreAppGroupID) }
        Bundle.cachedAltStoreAppGroup = appGroup
        return appGroup
    }
    
    var completeInfoDictionary: [String : Any]? {
        let infoPlistURL = self.infoPlistURL
        return NSDictionary(contentsOf: infoPlistURL) as? [String : Any]
    }
}
