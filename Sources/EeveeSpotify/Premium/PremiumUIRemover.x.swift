import Orion
import UIKit

// Hook UILabel to modify premium-related text
class UILabelHook: ClassHook<UILabel> {
    typealias Group = PremiumUIHooksGroup
    
    func setText(_ text: String?) {
        guard let text = text else {
            orig.setText(text)
            return
        }
        
        let modifiedText = modifyPremiumText(text)
        if modifiedText != text {
            writeDebugLog("[UI] Modified UILabel text: '\(text)' -> '\(modifiedText)'")
            orig.setText(modifiedText)
        } else {
            orig.setText(text)
        }
    }
    
    private func modifyPremiumText(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("spotify free") {
            return "EeveeSpotify"
        } else if lowercased.contains("premium") && !lowercased.contains("eevee") {
            return text.replacingOccurrences(of: "Premium", with: "EeveeSpotify Premium")
                .replacingOccurrences(of: "premium", with: "EeveeSpotify Premium")
        }
        
        return text
    }
}

// Hook UIImageView to remove premium-related icons
class UIImageViewHook: ClassHook<UIImageView> {
    typealias Group = PremiumUIHooksGroup
    
    func setImage(_ image: UIImage?) {
        guard let image = image else {
            orig.setImage(image)
            return
        }
        
        if isPremiumIcon(image) {
            writeDebugLog("[UI] Removed premium icon from UIImageView")
            orig.setImage(nil)
        } else {
            orig.setImage(image)
        }
    }
    
    private func isPremiumIcon(_ image: UIImage) -> Bool {
        // Check if the image has premium-related accessibility identifier
        if let accessibilityIdentifier = image.accessibilityIdentifier {
            let id = accessibilityIdentifier.lowercased()
            return id.contains("premium") || id.contains("badge")
        }
        
        // Check image size and properties that might indicate a premium badge
        let size = image.size
        if size.width <= 50 && size.height <= 50 {
            // Small square/circular images are often badges
            return true
        }
        
        return false
    }
}

// Hook UIButton to modify premium-related button text
class UIButtonHook: ClassHook<UIButton> {
    typealias Group = PremiumUIHooksGroup
    
    func setTitle(_ title: String?, for state: UIControl.State) {
        guard let title = title else {
            orig.setTitle(title, for: state)
            return
        }
        
        let modifiedTitle = modifyPremiumText(title)
        if modifiedTitle != title {
            writeDebugLog("[UI] Modified UIButton title: '\(title)' -> '\(modifiedTitle)'")
            orig.setTitle(modifiedTitle, for: state)
        } else {
            orig.setTitle(title, for: state)
        }
    }
    
    private func modifyPremiumText(_ text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("spotify free") {
            return "EeveeSpotify"
        } else if lowercased.contains("premium") && !lowercased.contains("eevee") {
            return text.replacingOccurrences(of: "Premium", with: "EeveeSpotify Premium")
                .replacingOccurrences(of: "premium", with: "EeveeSpotify Premium")
        }
        
        return text
    }
}
