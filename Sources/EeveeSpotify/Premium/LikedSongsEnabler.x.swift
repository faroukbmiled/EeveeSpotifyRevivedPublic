import Orion

private let likedTracksRow: [String: Any] = [
    "id": "artist-entity-view-liked-tracks-row",
    "text": [ "title": "liked_songs".localized ]
]

class HUBViewModelBuilderImplementationHook: ClassHook<NSObject> {
    typealias Group = PremiumUIHooksGroup
    static let targetName: String = "HUBViewModelBuilderImplementation"
    
    override init(target: NSObject) {
        writeDebugLog("[UI] HUBViewModelBuilderImplementationHook initialized")
        super.init(target: target)
    }
    
    func addJSONDictionary(_ dictionary: NSDictionary?) {
        writeDebugLog("[UI] HUBViewModelBuilderImplementationHook.addJSONDictionary called")
        guard let dictionary = dictionary else {
            writeDebugLog("[UI] HUBViewModelBuilderImplementationHook: dictionary is nil")
            return
        }
        
        let mutableDictionary = NSMutableDictionary(dictionary: dictionary)
        writeDebugLog("[UI] HUBViewModelBuilderImplementationHook: processing dictionary with id=\(dictionary["id"] as? String ?? "unknown")")
        
        let id = dictionary["id"] as? String
        
        // Comprehensive premium icon and text modification
        modifyPremiumUIElements(in: mutableDictionary)
        
        if id == "artist-entity-view" {
            guard var components = dictionary["body"] as? [[String: Any]] else {
                orig.addJSONDictionary(mutableDictionary)
                return
            }
            
            if let index = components.firstIndex(
                where: { $0["id"] as? String == "artist-entity-view-artist-tab-container" }
            ) {
                if var childrenArray = components[index]["children"] as? [[String: Any]],
                   var innerChildrenArray = childrenArray[0]["children"] as? [Any] {
                    
                    innerChildrenArray.insert(likedTracksRow, at: 0)
                    
                    childrenArray[0]["children"] = innerChildrenArray
                    components[index]["children"] = childrenArray
                }
            }
            else if let index = components.firstIndex(
                where: { $0["id"] as? String == "artist-entity-view-top-tracks-combined" }
            ) {
                components.insert(likedTracksRow, at: index)
            }
            
            mutableDictionary["body"] = components
        }
        
        orig.addJSONDictionary(mutableDictionary)
    }
    
    private func modifyPremiumUIElements(in dictionary: NSMutableDictionary) {
        // Recursively modify premium-related text and icons
        modifyPremiumText(in: dictionary)
        
        // Handle nested structures
        if let body = dictionary["body"] as? NSMutableArray {
            for item in body {
                if let dict = item as? NSMutableDictionary {
                    modifyPremiumUIElements(in: dict)
                }
            }
        }
        
        if let children = dictionary["children"] as? NSMutableArray {
            for item in children {
                if let dict = item as? NSMutableDictionary {
                    modifyPremiumUIElements(in: dict)
                }
            }
        }
    }
    
    private func modifyPremiumText(in dictionary: NSMutableDictionary) {
        // Modify text fields that contain premium references
        if let text = dictionary["text"] as? NSMutableDictionary {
            modifyTextDictionary(text)
        }
        
        if let title = dictionary["title"] as? String {
            if title.lowercased().contains("premium") || title.lowercased().contains("spotify free") {
                dictionary["title"] = "EeveeSpotify"
                writeDebugLog("[UI] Modified premium title to EeveeSpotify")
            }
        }
        
        if let subtitle = dictionary["subtitle"] as? String {
            if subtitle.lowercased().contains("premium") || subtitle.lowercased().contains("spotify free") {
                dictionary["subtitle"] = "Premium"
                writeDebugLog("[UI] Modified premium subtitle to Premium")
            }
        }
        
        // Handle image URLs that might contain premium icons
        if let imageUrl = dictionary["imageUri"] as? String {
            if imageUrl.lowercased().contains("premium") || imageUrl.lowercased().contains("badge") {
                dictionary["imageUri"] = "" // Remove premium badge images
                writeDebugLog("[UI] Removed premium badge image")
            }
        }
    }
    
    private func modifyTextDictionary(_ textDict: NSMutableDictionary) {
        if let title = textDict["title"] as? String {
            if title.lowercased().contains("premium") || title.lowercased().contains("spotify free") {
                textDict["title"] = "EeveeSpotify"
                writeDebugLog("[UI] Modified premium text title to EeveeSpotify")
            }
        }
        
        if let subtitle = textDict["subtitle"] as? String {
            if subtitle.lowercased().contains("premium") || subtitle.lowercased().contains("spotify free") {
                textDict["subtitle"] = "Premium"
                writeDebugLog("[UI] Modified premium text subtitle to Premium")
            }
        }
    }
}
