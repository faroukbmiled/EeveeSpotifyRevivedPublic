import Orion

private let likedTracksRow: [String: Any] = [
    "id": "artist-entity-view-liked-tracks-row",
    "text": [ "title": "liked_songs".localized ]
]

class HUBViewModelBuilderImplementationHook: ClassHook<NSObject> {
    typealias Group = PremiumUIHooksGroup
    static let targetName: String = "HUBViewModelBuilderImplementation"
    
    func addJSONDictionary(_ dictionary: NSDictionary?) {
        writeDebugLog("[UI] HUBViewModelBuilderImplementationHook.addJSONDictionary called")
        guard let dictionary = dictionary else {
            writeDebugLog("[UI] HUBViewModelBuilderImplementationHook: dictionary is nil")
            return
        }
        
        let mutableDictionary = NSMutableDictionary(dictionary: dictionary)
        writeDebugLog("[UI] HUBViewModelBuilderImplementationHook: processing dictionary with id=\(dictionary["id"] as? String ?? "unknown")")
        
        let id = dictionary["id"] as? String
        
        if id == "artist-entity-view" {
            guard var components = dictionary["body"] as? [[String: Any]] else {
                orig.addJSONDictionary(dictionary)
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
}
