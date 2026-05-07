import Foundation

/// When bootstrap/`v1/customize` are missed (e.g. second auth lifecycle on 9.1.34+), Spotify still pushes
/// product state via `[SPTAuthSessionImplementation productStateUpdated:]`. Rewrite obvious free-tier maps.
func eeveePremiumCoercedProductStateIfNeeded(for state: AnyObject) -> (AnyObject, Bool) {
    let elapsed = Int(Date().timeIntervalSince(tweakInitTime))
    writeDebugLog("[AUTH] ProductState coercion check at \(elapsed)s, patchType=\(UserDefaults.patchType)")
    
    guard UserDefaults.patchType.isPatching else { 
        writeDebugLog("[AUTH] Skipping coercion - patchType not enabled")
        return (state, false) 
    }
    
    guard let dict = state as? NSDictionary else { 
        writeDebugLog("[AUTH] Skipping coercion - state is not NSDictionary")
        return (state, false) 
    }
    
    // Log key product state values for debugging
    let type = eeveeNormKey(dict, "type")
    let catalogue = eeveeNormKey(dict, "catalogue")
    let fp = eeveeNormKey(dict, "financial-product")
    let name = eeveeNormKey(dict, "name")
    let ads = dict["ads"] as? Int ?? -1
    
    writeDebugLog("[AUTH] ProductState analysis - type:\(type), catalogue:\(catalogue), fp:\(fp), name:\(name), ads:\(ads)")
    
    // Enhanced v9.1.34+ compatibility: Always coerce if patching is enabled, regardless of current state
    // This handles rapid state updates that can overwrite coerced premium state
    if EeveeSpotify.hookTarget == .v91 && UserDefaults.patchType.isPatching {
        writeDebugLog("[AUTH] v9.1.x detected with patching enabled - forcing coercion to prevent rapid state overwrites")
        let mutable = NSMutableDictionary(dictionary: dict)
        eeveeApplyPremiumProductStateKeys(to: mutable)
        eeveeStripFreeTierLeakKeys(from: mutable)
        writeDebugLog("[AUTH] Forced coercion applied for v9.1.x stability")
        return (mutable as AnyObject, true)
    }
    
    // Original logic for other versions
    guard eeveeProductStateAppearsFreeTier(dict) else { 
        writeDebugLog("[AUTH] Skipping coercion - productState does not appear free-tier")
        return (state, false) 
    }

    writeDebugLog("[AUTH] Free-tier detected, applying coercion")
    let mutable = NSMutableDictionary(dictionary: dict)
    eeveeApplyPremiumProductStateKeys(to: mutable)
    eeveeStripFreeTierLeakKeys(from: mutable)
    writeDebugLog("[AUTH] Coerced free-tier productState to premium-compatible map")
    return (mutable as AnyObject, true)
}

private func eeveeNormKey(_ dict: NSDictionary, _ key: String) -> String {
    guard let v = dict[key] else { return "" }
    return String(describing: v).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

private func eeveeProductStateAppearsFreeTier(_ dict: NSDictionary) -> Bool {
    let t = eeveeNormKey(dict, "type")
    let catalogue = eeveeNormKey(dict, "catalogue")
    let fp = eeveeNormKey(dict, "financial-product")
    let name = eeveeNormKey(dict, "name")
    let license = eeveeNormKey(dict, "player-license")
    let licenseV2 = eeveeNormKey(dict, "player-license-v2")
    let hasAds = dict["ads"] as? Int == 1
    
    // Ultra-aggressive detection for v9.1.34+ - catch ANY possible free-tier indicator
    let isFreeType = t == "free" || catalogue == "free" || fp.contains("pr:free")
    let isFreeName = name.contains("free") || name.contains("ad-supported")
    let isFreeLicense = license.contains("free") || licenseV2.contains("free")
    let hasAds = dict["ads"] as? Int == 1
    
    // Additional checks for v9.1.34 edge cases
    let hasAdsFlag = dict["ads"] != nil
    let hasNoPremiumFlags = (dict["offline"] as? Int != 1) || (dict["on-demand"] as? Int != 1)
    let hasFreeLicenseText = license.lowercased().contains("free") || licenseV2.lowercased().contains("free")
    let hasFreeCatalogue = catalogue.lowercased().contains("free")
    
    let isFreeTier = isFreeType || isFreeName || isFreeLicense || hasAds || hasAdsFlag || hasNoPremiumFlags || hasFreeLicenseText || hasFreeCatalogue
    
    if isFreeTier {
        writeDebugLog("[AUTH] Ultra-aggressive free-tier detection triggered - multiple indicators found")
    }
    
    return isFreeTier
}

private func eeveeApplyPremiumProductStateKeys(to m: NSMutableDictionary) {
    let oneYearFromNow = Calendar.current.date(byAdding: .year, value: 1, to: Date())!
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(abbreviation: "UTC")
    let end = formatter.string(from: oneYearFromNow)

    let z = NSNumber(value: 0), o = NSNumber(value: 1)

    m["catalogue"] = "premium"
    m["type"] = "premium"
    m["name"] = "Spotify Premium"
    m["financial-product"] = "pr:premium,tc:0"

    m["ads"] = z
    m["ab-ad-player-targeting"] = z
    m["allow-advertising-id-transmission"] = z
    m["restrict-advertising-id-transmission"] = o
    m["can_use_superbird"] = o
    m["is-eligible-premium-unboxing"] = o

    m["nft-disabled"] = "1"
    m["offline"] = o
    m["on-demand"] = o

    m["player-license"] = "premium"
    m["player-license-v2"] = "premium"

    m["payments-initial-campaign"] = "default"
    m["product-expiry"] = end
    m["subscription-enddate"] = end
    m["shuffle-eligible"] = o

    m["social-session"] = o
    m["social-session-free-tier"] = z
    m["streaming-rules"] = ""

    m["unrestricted"] = o
}

private func eeveeStripFreeTierLeakKeys(from m: NSMutableDictionary) {
    [
        "on-demand-trial", "on-demand-trial-in-progress", "smart-shuffle",
        "at-signal", "feature-set-id-masked", "strider-key",
        "payment-state", "last-premium-activation-date",
    ].forEach { m.removeObject(forKey: $0) }
}
