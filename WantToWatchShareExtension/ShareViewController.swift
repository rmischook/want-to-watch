//
//  ShareViewController.swift
//  WantToWatchShareExtension
//
//  Created on 21/04/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import NaturalLanguage

/// Shared ModelContainer for the extension
private let sharedModelContainer: ModelContainer = {
    guard let appGroupURL = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.com.rmischook.WantToWatch"
    ) else {
        fatalError("App Groups container not available")
    }
    
    let storeURL = appGroupURL.appendingPathComponent("default.store")
    
    let schema = Schema([WatchlistItem.self])
    let configuration = ModelConfiguration(
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .private("iCloud.com.rmischook.WantToWatch")
    )
    
    do {
        return try ModelContainer(for: schema, configurations: configuration)
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSLog("[ShareExtension] ========== viewDidLoad START ==========")
        NSLog("[ShareExtension] extensionContext: \(String(describing: extensionContext))")
        NSLog("[ShareExtension] inputItems count: \(extensionContext?.inputItems.count ?? -1)")
        
        // Get the shared content
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem else {
            NSLog("[ShareExtension] No extension item found - showing manual search")
            showManualSearch()
            return
        }
        
        NSLog("[ShareExtension] Extension item: \(extensionItem)")
        NSLog("[ShareExtension] Attachments: \(extensionItem.attachments ?? [])")
        
        guard let attachments = extensionItem.attachments, !attachments.isEmpty else {
            showError("No attachments found")
            return
        }
        
        // Try each attachment - prioritize URL over text
        for itemProvider in attachments {
            NSLog("[ShareExtension] ItemProvider: \(itemProvider)")
            NSLog("[ShareExtension] Registered types: \(itemProvider.registeredTypeIdentifiers)")
            
            // Try URL first
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                NSLog("[ShareExtension] Found URL type")
                loadURL(from: itemProvider)
                return
            }
        }
        
        // No URL found, try text
        for itemProvider in attachments {
            // Try plain text (might be a URL string or share text)
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                NSLog("[ShareExtension] Found plain text type")
                loadText(from: itemProvider)
                return
            }
            
            // Try property list (some apps share URLs this way)
            if itemProvider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                NSLog("[ShareExtension] Found property list type")
                loadPropertyList(from: itemProvider)
                return
            }
        }
        
        NSLog("[ShareExtension] No supported content type found, showing manual search")
        showManualSearch()
    }
    
    private func loadURL(from itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] result, error in
            if let error = error {
                NSLog("[ShareExtension] URL load error: \(error)")
                DispatchQueue.main.async {
                    self?.showError("Failed to load URL: \(error.localizedDescription)")
                }
                return
            }
            
            if let url = result as? URL {
                NSLog("[ShareExtension] Loaded URL: \(url)")
                DispatchQueue.main.async {
                    self?.handleSharedURL(url)
                }
            } else if let urlString = result as? String {
                NSLog("[ShareExtension] Loaded URL string: \(urlString)")
                if let url = URL(string: urlString) {
                    DispatchQueue.main.async {
                        self?.handleSharedURL(url)
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.showError("Invalid URL: \(urlString)")
                    }
                }
            } else {
                NSLog("[ShareExtension] Unknown URL result type: \(type(of: result))")
                DispatchQueue.main.async {
                    self?.showError("Could not parse URL")
                }
            }
        }
    }
    
    private func loadText(from itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] result, error in
            if let error = error {
                NSLog("[ShareExtension] Text load error: \(error)")
                DispatchQueue.main.async {
                    self?.showError("Failed to load text: \(error.localizedDescription)")
                }
                return
            }
            
            if let text = result as? String {
                NSLog("[ShareExtension] Loaded text: \(text)")
                
                // Check if it looks like a URL
                if text.contains("://") || text.hasPrefix("www.") {
                    if let url = URL(string: text) {
                        DispatchQueue.main.async {
                            self?.handleSharedURL(url)
                        }
                        return
                    }
                }
                
                // It's not a URL - extract title and search
                let extractedTitle = self?.extractTitleFromText(text)
                NSLog("[ShareExtension] Extracted title: \(extractedTitle ?? "nil")")
                
                DispatchQueue.main.async {
                    self?.handleSharedText(text, extractedTitle: extractedTitle)
                }
            }
        }
    }
    
    private func extractTitleFromText(_ text: String) -> String? {
        // First try regex patterns (most reliable for known formats)
        if let regexTitle = extractTitleWithRegex(text) {
            NSLog("[ShareExtension] Regex extracted: \(regexTitle)")
            return regexTitle
        }
        
        // Fall back to NLP-based extraction for unknown formats
        if let nlpTitle = extractTitleWithNLP(text) {
            NSLog("[ShareExtension] NLP extracted: \(nlpTitle)")
            return nlpTitle
        }
        
        return nil
    }
    
    private func extractTitleWithRegex(_ text: String) -> String? {
        // Netflix pattern: Check out "Title" on Netflix
        // Apple TV pattern: Watch "Title" on Apple TV
        // Prime Video pattern: Hey I'm watching Title. Check it out now on Prime Video!
        // General: Look for quoted text
        
        // Try Prime Video pattern first
        let primePattern = #"I'm watching (.+?)\..*Prime Video"#
        if let regex = try? NSRegularExpression(pattern: primePattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        // Try to match text in quotes
        let quotePattern = #"\"([^\"]+)\""#
        
        if let regex = try? NSRegularExpression(pattern: quotePattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        // Try curly quotes too
        let curlyQuotePattern = "[\u{201C}\u{201D}]([^\u{201C}\u{201D}]+)[\u{201C}\u{201D}]"
        
        if let regex = try? NSRegularExpression(pattern: curlyQuotePattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        
        return nil
    }
    
    private func extractTitleWithNLP(_ text: String) -> String? {
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = text
        
        // Known streaming service names to exclude
        let excludedOrganizations: Set<String> = [
            "netflix", "prime video", "amazon prime", "amazon", "apple tv",
            "disney+", "disney plus", "hulu", "hbo", "hbo max", "max",
            "paramount+", "peacock", "now tv", "britbox", "youtube"
        ]
        
        var candidates: [(text: String, score: Int)] = []
        var currentProperNounSequence = ""
        
        // Iterate through tokens
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, tokenRange in
            let word = String(text[tokenRange])
            
            if tag == .noun {
                // Check if it's part of a proper noun sequence (likely a title)
                let isCapitalized = word.first?.isUppercase ?? false
                
                if isCapitalized {
                    if currentProperNounSequence.isEmpty {
                        currentProperNounSequence = word
                    } else {
                        currentProperNounSequence += " " + word
                    }
                } else {
                    // End of proper noun sequence
                    if !currentProperNounSequence.isEmpty {
                        candidates.append((currentProperNounSequence, currentProperNounSequence.split(separator: " ").count))
                        currentProperNounSequence = ""
                    }
                }
            } else {
                // End of proper noun sequence
                if !currentProperNounSequence.isEmpty {
                    candidates.append((currentProperNounSequence, currentProperNounSequence.split(separator: " ").count))
                    currentProperNounSequence = ""
                }
            }
            
            return true
        }
        
        // Don't forget the last sequence
        if !currentProperNounSequence.isEmpty {
            candidates.append((currentProperNounSequence, currentProperNounSequence.split(separator: " ").count))
        }
        
        // Now filter out named entities that are organizations or locations
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
            if tag == .organizationName || tag == .placeName {
                let entity = String(text[tokenRange]).lowercased()
                // Mark candidates that match known organizations for removal
                candidates = candidates.map { candidate in
                    if candidate.text.lowercased().contains(entity) || excludedOrganizations.contains(candidate.text.lowercased()) {
                        return (candidate.text, -1) // Mark for removal
                    }
                    return candidate
                }
            }
            return true
        }
        
        // Filter out marked candidates and short single words
        let validCandidates = candidates
            .filter { $0.score > 0 && $0.text.count > 2 }
            .sorted { $0.score > $1.score } // Prefer longer sequences
        
        // Return the best candidate (longest proper noun sequence)
        if let best = validCandidates.first {
            return best.text
        }
        
        return nil
    }
    
    private func loadPropertyList(from itemProvider: NSItemProvider) {
        itemProvider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { [weak self] result, error in
            if let error = error {
                NSLog("[ShareExtension] Property list load error: \(error)")
                DispatchQueue.main.async {
                    self?.showError("Failed to load data: \(error.localizedDescription)")
                }
                return
            }
            
            if let dict = result as? [String: Any] {
                NSLog("[ShareExtension] Property list: \(dict)")
                // Try to extract URL from common keys
                if let url = dict["url"] as? URL {
                    DispatchQueue.main.async {
                        self?.handleSharedURL(url)
                    }
                } else if let urlString = dict["url"] as? String, let url = URL(string: urlString) {
                    DispatchQueue.main.async {
                        self?.handleSharedURL(url)
                    }
                } else if let results = dict[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
                    // Safari share extension results
                    if let urlString = results["url"] as? String, let url = URL(string: urlString) {
                        DispatchQueue.main.async {
                            self?.handleSharedURL(url)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.showError("Could not extract URL from data")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.showError("Unexpected data format")
                }
            }
        }
    }
    
    private func handleSharedURL(_ url: URL) {
        NSLog("[ShareExtension] Handling URL: \(url.absoluteString)")
        
        // Create the share view
        let shareView = ShareSheetView(
            sharedURL: url,
            initialSearchText: nil,
            modelContainer: sharedModelContainer,
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: ShareError.cancelled)
            }
        )
        
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
    
    private func handleSharedText(_ originalText: String, extractedTitle: String?) {
        NSLog("[ShareExtension] Handling shared text with extracted title: \(extractedTitle ?? "nil")")
        
        // Use extracted title, or fall back to original text
        let searchText = extractedTitle ?? originalText
        
        // Create the share view with the search text
        let shareView = ShareSheetView(
            sharedURL: nil,
            initialSearchText: searchText,
            modelContainer: sharedModelContainer,
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: ShareError.cancelled)
            }
        )
        
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.extensionContext?.cancelRequest(withError: ShareError.noContent)
        })
        present(alert, animated: true)
    }
    
    private func showManualSearch() {
        NSLog("[ShareExtension] Showing manual search")
        
        let shareView = ShareSheetView(
            sharedURL: nil,
            initialSearchText: "",
            modelContainer: sharedModelContainer,
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            },
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: ShareError.cancelled)
            }
        )
        
        let hostingController = UIHostingController(rootView: shareView)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }
}

enum ShareError: Error {
    case noContent
    case cancelled
}
