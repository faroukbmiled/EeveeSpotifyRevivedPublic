import Foundation
import Orion

// Global variable for access token
public var spotifyAccessToken: String?

// Helper function to start capturing from other files
func DataLoaderServiceHooks_startCapturing() {
}

class SPTDataLoaderServiceHook: ClassHook<NSObject>, SpotifySessionDelegate {
    // Intercepts various responses (customize/plan/lyrics) and now also bootstrap for 9.1.x stability.
    typealias Group = PremiumBootstrapGroup
    static let targetName = "SPTDataLoaderService"

    // orion:new
    static var cachedCustomizeData: Data?

    // orion:new
    static var handledCustomizeTasks = Set<Int>()

    // orion:new
    func shouldBlock(_ url: URL) -> Bool {
        let elapsed = Date().timeIntervalSince(tweakInitTime)
        let elapsedInt = Int(elapsed)
        let path = url.path.lowercased()
        
        writeDebugLog("[DL] shouldBlock checking \(url.absoluteString) at \(elapsedInt)s")
        
        // Always block explicit session destroy/token delete or ad-related requests
        if url.isDeleteToken || url.isSessionInvalidation || path.contains("session/purge") || path.contains("token/revoke") || url.isAdRelated {
            writeDebugLog("[DL] Blocking \(url.absoluteString) - session destroy/ad related")
            return true
        }
        
        // Block all DAC (Display Ad Container) ad requests.
        // The DAC endpoint delivers the search-page and home-page display ads
        // (e.g. Cartier on Search, Ross on Home shown in the screenshots).
        // Any /dac/view/v1/ request is ad-related; return empty to suppress.
        if path.contains("/dac/view/v1/") {
            writeDebugLog("[DL] Blocking \(url.absoluteString) - DAC ad request")
            return true
        }

        // Block the Esperanto ad slot service used for in-stream and overlay ads
        if path.contains("/esperanto/") && (path.contains("ad") || path.contains("slot")) {
            writeDebugLog("[DL] Blocking \(url.absoluteString) - Esperanto ad slot")
            return true
        }

        // Only block these after startup (30s) to allow initial login/initialization
        if elapsed > 30 {
            let shouldBlock = url.isAccountValidate || url.isOndemandSelector
                || url.isTrialsFacade || url.isPremiumMarketing || url.isPendragonFetchMessageList
                || url.isPushkaTokens || url.path.contains("signup/public") || url.path.contains("apresolve")
                || url.path.contains("pses/screenconfig")
                // Block periodic customize re-fetches (RemoteConfigurationSDK AuthFetcher).
                // The AuthFetcher re-fetches v1/customize after minimumFetchIntervalSeconds
                // (typically a few hours). If this re-fetch is not intercepted and modified,
                // the app re-enables ad feature flags from the server response.
                // We block re-fetches here; the cached modified data is served via the 304 path.
                || url.path.contains("v1/customize")
            
            if shouldBlock {
                writeDebugLog("[DL] Blocking \(url.absoluteString) - post-30s protection")
                return true
            }
        }
        
        writeDebugLog("[DL] Allowing \(url.absoluteString) - no block conditions met")
        return false
    }

    // orion:new
    func shouldModifyResponse(for url: URL) -> Bool {
        let patchRequests = UserDefaults.patchType.isPatching
        let shouldReplaceLyrics = UserDefaults.lyricsSource.isReplacingLyrics
        let isLyricsURL = url.isLyrics
        
        // Debug logging for premium UI endpoints
        if url.isPremiumPlanRow {
            writeDebugLog("[UI] shouldModifyResponse: GetPremiumPlanRow detected, patchRequests=\(patchRequests)")
        }
        if url.isPremiumBadge {
            writeDebugLog("[UI] shouldModifyResponse: GetYourPremiumBadge detected, patchRequests=\(patchRequests)")
        }
        
        // Debug logging for potential premium status endpoints
        if url.path.contains("accountsettings") || url.path.contains("profile") {
            writeDebugLog("[UI] shouldModifyResponse: Account/Profile endpoint detected: \(url.path), patchRequests=\(patchRequests)")
        }
        
        // Bootstrap must patch even while PremiumBootstrapGroup.isActive is briefly false during Orion/session reinits.
        let shouldModify = (patchRequests && url.isBootstrap)
            || (shouldReplaceLyrics && isLyricsURL)
            || ((BasePremiumPatchingGroup.isActive || PremiumBootstrapGroup.isActive) && (url.isCustomize || url.isPremiumPlanRow || url.isPremiumBadge || url.isPlanOverview || url.path.contains("accountsettings")))
        
        if (url.isPremiumPlanRow || url.isPremiumBadge) && shouldModify {
            writeDebugLog("[UI] shouldModifyResponse: Will modify premium UI endpoint")
        } else if (url.isPremiumPlanRow || url.isPremiumBadge) && !shouldModify {
            writeDebugLog("[UI] shouldModifyResponse: Will NOT modify premium UI endpoint - condition not met")
        }
        
        return shouldModify
    }
    
    // orion:new
    func respondWithCustomData(_ data: Data, task: URLSessionDataTask, session: URLSession) {
        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }

    // orion:new
    func handleBlockedEndpoint(_ url: URL, task: URLSessionDataTask, session: URLSession) {
        if url.isDeleteToken {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isAccountValidate {
            let response = "{\"status\":1,\"country\":\"US\",\"is_country_launched\":true}".data(using: .utf8)!
            respondWithCustomData(response, task: task, session: session)
        } else if url.isOndemandSelector {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isTrialsFacade {
            let response = "{\"result\":\"NOT_ELIGIBLE\"}".data(using: .utf8)!
            respondWithCustomData(response, task: task, session: session)
        } else if url.isPremiumMarketing {
            respondWithCustomData("{}".data(using: .utf8)!, task: task, session: session)
        } else if url.isPendragonFetchMessageList {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isPushkaTokens {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.isSessionInvalidation || url.path.contains("session/purge") || url.path.contains("token/revoke") {
            // Return synthetic OK to prevent internal logout triggers
            respondWithCustomData("{\"status\":\"OK\"}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("signup/public") {
            respondWithCustomData("{\"status\":\"OK\"}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("apresolve") {
            respondWithCustomData("{\"status\":\"OK\"}".data(using: .utf8)!, task: task, session: session)
        } else if url.path.contains("pses/screenconfig") {
            respondWithCustomData("{}".data(using: .utf8)!, task: task, session: session)
        } else if url.isAdRelated {
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.path.lowercased().contains("/dac/view/v1/") {
            // Return empty data for DAC ad requests
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.path.lowercased().contains("/esperanto/") {
            // Return empty data for Esperanto ad slot requests
            respondWithCustomData(Data(), task: task, session: session)
        } else if url.path.contains("v1/customize") {
            // Serve the cached modified customize data for periodic re-fetches
            if let cached = SPTDataLoaderServiceHook.cachedCustomizeData {
                respondWithCustomData(cached, task: task, session: session)
            } else {
                respondWithCustomData(Data(), task: task, session: session)
            }
        }
        orig.URLSession(session, task: task, didCompleteWithError: nil)
    }
    
    func URLSession(
        _ session: URLSession,
        task: URLSessionDataTask,
        didCompleteWithError error: Error?
    ) {
        // Capture authorization token from any request
        if let request = task.currentRequest,
           let headers = request.allHTTPHeaderFields,
           let auth = headers["Authorization"] ?? headers["authorization"],
           auth.hasPrefix("Bearer ") {
            spotifyAccessToken = String(auth.dropFirst(7))
        }
	
        guard let url = task.currentRequest?.url else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }

        // Handle blocked endpoints (session protection)
        if shouldBlock(url) {
            handleBlockedEndpoint(url, task: task, session: session)
            return
        }

        // Handle customize 304 that was already served in didReceiveResponse
        if SPTDataLoaderServiceHook.handledCustomizeTasks.remove(task.taskIdentifier) != nil {
            orig.URLSession(session, task: task, didCompleteWithError: nil)
            return
        }

        guard error == nil, shouldModifyResponse(for: url) else {
            orig.URLSession(session, task: task, didCompleteWithError: error)
            return
        }
        
        guard let buffer = URLSessionHelper.shared.obtainData(for: url) else {
            if url.isBootstrap {
                writeDebugLog("[BOOTSTRAP] (DL) No buffered body (delegate/other path consumed it) — completing original")
                orig.URLSession(session, task: task, didCompleteWithError: error)
                return
            }
            // Customize 304 fallback: serve cached modified data when no buffer available
            if url.isCustomize, let cached = SPTDataLoaderServiceHook.cachedCustomizeData {
                respondWithCustomData(cached, task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
            }
            return
        }
        
        do {
            if url.isLyrics {
                let originalLyrics = try? Lyrics(serializedBytes: buffer)
                
                // Try to fetch custom lyrics with a timeout
                let semaphore = DispatchSemaphore(value: 0)
                var customLyricsData: Data?
                
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        customLyricsData = try getLyricsDataForCurrentTrack(
                            url.path,
                            originalLyrics: originalLyrics
                        )
                    } catch {
                    }
                    semaphore.signal()
                }
                
                // Wait up to 5 seconds for custom lyrics
                let timeout = DispatchTime.now() + .milliseconds(5000)
                let result = semaphore.wait(timeout: timeout)
                
                if result == .success, let data = customLyricsData {
                    respondWithCustomData(data, task: task, session: session)
                    orig.URLSession(session, task: task, didCompleteWithError: nil)
                } else {
                    respondWithCustomData(buffer, task: task, session: session)
                    orig.URLSession(session, task: task, didCompleteWithError: nil)
                }
                return
            }
            
            if url.isPremiumPlanRow {
                writeDebugLog("[UI] Intercepting GetPremiumPlanRow request - applying EeveeSpotify branding")
                respondWithCustomData(
                    try getPremiumPlanRowData(
                        originalPremiumPlanRow: try PremiumPlanRow(serializedBytes: buffer)
                    ),
                    task: task,
                    session: session
                )
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            
            if url.isPremiumBadge {
                writeDebugLog("[UI] Intercepting GetYourPremiumBadge request - applying EeveeSpotify branding")
                respondWithCustomData(try getPremiumPlanBadge(), task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            
            if url.path.contains("accountsettings") {
                writeDebugLog("[UI] Intercepting accountsettings request - checking for premium status fields")
                // Try to parse and modify account settings if they contain premium status
                if let jsonString = String(data: buffer, encoding: .utf8) {
                    let jsonData = jsonString.data(using: .utf8)
                    do {
                        if let json = try JSONSerialization.jsonObject(with: jsonData ?? Data()) as? [String: Any] {
                            var mutableJson = json
                            // Look for premium status fields and modify them
                            if let product = mutableJson["product"] as? [String: Any] {
                                var modifiedProduct = product
                                modifiedProduct["type"] = "premium"
                                modifiedProduct["catalogue"] = "premium"
                                modifiedProduct["name"] = "EeveeSpotify Premium"
                                mutableJson["product"] = modifiedProduct
                                writeDebugLog("[UI] Modified accountsettings premium status")
                            }
                            
                            let modifiedData = try JSONSerialization.data(withJSONObject: mutableJson)
                            respondWithCustomData(modifiedData, task: task, session: session)
                            orig.URLSession(session, task: task, didCompleteWithError: nil)
                            return
                        }
                    } catch {
                        writeDebugLog("[UI] Failed to modify accountsettings JSON: \(error)")
                    }
                }
            }
            
            if url.isBootstrap {
                // Patch bootstrap on the SPTDataLoaderService path too.
                // Some builds / sessions do not hit SpotifySessionDelegateBootstrapHook reliably.
                var bootstrapMessage = try BootstrapMessage(serializedBytes: buffer)
                if UserDefaults.patchType == .requests {
                    writeDebugLog("[BOOTSTRAP] (DL) Patching bootstrap UCS response")
                    eeveeNoteBootstrapPremiumPatchApplied()
                    modifyRemoteConfiguration(&bootstrapMessage.ucsResponse)
                } else {
                    writeDebugLog("[BOOTSTRAP] (DL) Passing through bootstrap (patchType=\(UserDefaults.patchType))")
                }
                respondWithCustomData(try bootstrapMessage.serializedBytes(), task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }

            if url.isCustomize {
                var customizeMessage = try CustomizeMessage(serializedBytes: buffer)
                modifyRemoteConfiguration(&customizeMessage.response)
                let modifiedData = try customizeMessage.serializedData()
                SPTDataLoaderServiceHook.cachedCustomizeData = modifiedData
                respondWithCustomData(modifiedData, task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
            
            if url.isPlanOverview {
                respondWithCustomData(try getPlanOverviewData(), task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }

            if url.path.lowercased().contains("/dac/view/v1/") {
                // For DAC responses, we return an empty valid response to hide ads/upsells
                // Most DAC endpoints expect a protobuf or JSON response.
                // Returning empty data or a minimal valid object is safer than blocking.
                respondWithCustomData(Data(), task: task, session: session)
                orig.URLSession(session, task: task, didCompleteWithError: nil)
                return
            }
        }
        catch {
            orig.URLSession(session, task: task, didCompleteWithError: error)
        }
    }

    func URLSession(
        _ session: URLSession,
        dataTask task: URLSessionDataTask,
        didReceiveResponse response: HTTPURLResponse,
        completionHandler handler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        // Handle customize 304 — prevent free-account data leaking from URLSession cache
        if let url = task.currentRequest?.url, url.isCustomize, response.statusCode == 304 {
            if let cached = SPTDataLoaderServiceHook.cachedCustomizeData {
                let fakeResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:])!
                orig.URLSession(session, dataTask: task, didReceiveResponse: fakeResponse, completionHandler: handler)
                respondWithCustomData(cached, task: task, session: session)
                SPTDataLoaderServiceHook.handledCustomizeTasks.insert(task.taskIdentifier)
                return
            }
        }

        guard
            let url = task.currentRequest?.url,
            url.isLyrics,
            response.statusCode != 200
        else {
            orig.URLSession(session, dataTask: task, didReceiveResponse: response, completionHandler: handler)
            return
        }

        do {
            let data = try getLyricsDataForCurrentTrack(url.path)
            let okResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "2.0", headerFields: [:])!
            
            orig.URLSession(session, dataTask: task, didReceiveResponse: okResponse, completionHandler: handler)
            respondWithCustomData(data, task: task, session: session)
        } catch {
            orig.URLSession(session, task: task, didCompleteWithError: error)
        }
    }

    func URLSession(
        _ session: URLSession,
        dataTask task: URLSessionDataTask,
        didReceiveData data: Data
    ) {
        guard let url = task.currentRequest?.url else {
            return
        }

        // Suppress data for blocked endpoints (prevent original data from reaching handler)
        if shouldBlock(url) {
            return
        }

        if shouldModifyResponse(for: url) {
            URLSessionHelper.shared.setOrAppend(data, for: url)
            return
        }

        orig.URLSession(session, dataTask: task, didReceiveData: data)
    }
}
