import SwiftUI
import WebKit

struct WebGameView: UIViewRepresentable {
    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var parent: WebGameView
        init(parent: WebGameView) { self.parent = parent }

        // Receive HUD updates from JS
        func userContentController(_ userContentController: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == "hud" else { return }
            
            // Safely extract values with error handling
            guard let dict = message.body as? [String: Any] else {
                print("Warning: HUD message body is not a dictionary")
                return
            }
            
            let score = (dict["score"] as? Int) ?? (dict["score"] as? Double).map(Int.init) ?? 0
            let best  = (dict["best"] as? Int) ?? (dict["best"] as? Double).map(Int.init) ?? 0
            let moves = (dict["moves"] as? Int) ?? (dict["moves"] as? Double).map(Int.init) ?? 0
            
            DispatchQueue.main.async {
                self.parent.onHUD(score, best, moves)
            }
        }
        
        // Navigation delegate methods for debugging
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView failed to load: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView failed provisional navigation: \(error.localizedDescription)")
        }
    }

    // Callbacks to ContentView
    var onHUD: (_ score: Int, _ best: Int, _ moves: Int) -> Void

    // We keep a reference so ContentView can call JS (e.g., newGame)
    @Binding var webRef: WKWebView?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let ucc = WKUserContentController()
        ucc.add(context.coordinator, name: "hud")
        config.userContentController = ucc
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.navigationDelegate = context.coordinator

        // Try to load from bundle file first, fallback to embedded if not found
        var htmlURL: URL?
        let pathsToTry = [
            ("index", "html", "game"),
            ("index", "html", "Resources/game"),
            ("index", "html", nil), // root of bundle
        ]
        
        print("DEBUG: Looking for game HTML file...")
        for (name, ext, subdir) in pathsToTry {
            if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir) {
                htmlURL = url
                print("✓ Found game file at: \(url.path)")
                break
            } else {
                print("✗ Not found: \(subdir ?? "root")/\(name).\(ext)")
            }
        }
        
        // Debug: List bundle contents if file not found
        if htmlURL == nil {
            print("DEBUG: Listing bundle resources...")
            if let resourcePath = Bundle.main.resourcePath {
                print("Bundle resource path: \(resourcePath)")
                if let contents = try? FileManager.default.contentsOfDirectory(atPath: resourcePath) {
                    print("Bundle contents: \(contents.prefix(20))")
                }
            }
            
            // Try to load from source directory (for development)
            #if DEBUG
            let sourcePaths = [
                Bundle.main.bundlePath + "/../../../../Resources/game/index.html",
                Bundle.main.bundlePath + "/../../../../../Connect/Resources/game/index.html",
                ProcessInfo.processInfo.environment["PROJECT_DIR"]?.appending("/Connect/Resources/game/index.html") ?? ""
            ]
            
            for sourcePath in sourcePaths {
                let url = URL(fileURLWithPath: sourcePath)
                if FileManager.default.fileExists(atPath: sourcePath) {
                    print("✓ Found game file in source: \(sourcePath)")
                    htmlURL = url
                    break
                }
            }
            #endif
        }
        
        if let url = htmlURL {
            print("Loading Match-3 Canvas game from file")
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else {
            // Fallback: Try to load HTML content from file system
            print("WARNING: Could not find game file in bundle, trying to load from source...")
            if loadGameFromSourceFile(web) {
                print("✓ Loaded game from source file")
            } else {
                print("✗ Could not load from source, using embedded HTML fallback")
                loadGameFromString(web)
            }
        }
        
        DispatchQueue.main.async { self.webRef = web } // hand reference to parent
        return web
    }
    
    private func loadGameFromSourceFile(_ webView: WKWebView) -> Bool {
        // Try common source file locations
        let possiblePaths = [
            // Relative to bundle
            Bundle.main.bundlePath + "/../../../../Resources/game/index.html",
            Bundle.main.bundlePath + "/../../../../../Connect/Resources/game/index.html",
            // Absolute paths that might work
            "/Users/christopherrydberg/Documents/Connect/Connect/Resources/game/index.html"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                if let htmlContent = try? String(contentsOfFile: path, encoding: .utf8) {
                    webView.loadHTMLString(htmlContent, baseURL: URL(fileURLWithPath: (path as NSString).deletingLastPathComponent))
                    return true
                }
            }
        }
        return false
    }
    
    private func loadGameFromString(_ webView: WKWebView) {
        let htmlString = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Connections</title>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                    background: #1a1a2e;
                    color: #fff;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    min-height: 100vh;
                    padding: 20px;
                }
                .game-container { max-width: 420px; width: 100%; }
                .grid {
                    display: grid;
                    grid-template-columns: repeat(4, 1fr);
                    gap: 8px;
                    margin-bottom: 20px;
                }
                .tile {
                    aspect-ratio: 1;
                    background: #2d2d44;
                    border: 2px solid #3d3d5c;
                    border-radius: 8px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-weight: 600;
                    font-size: 14px;
                    cursor: pointer;
                    transition: all 0.2s;
                    text-align: center;
                    padding: 8px;
                }
                .tile:hover { background: #3d3d5c; transform: scale(1.05); }
                .tile.selected { background: #4a90e2; border-color: #5aa0f2; }
                .tile.matched { background: #2ecc71; border-color: #27ae60; opacity: 0.6; }
                .groups { margin-top: 20px; }
                .group { display: flex; gap: 8px; margin-bottom: 12px; min-height: 50px; }
                .group-slot {
                    flex: 1;
                    background: #2d2d44;
                    border: 2px dashed #3d3d5c;
                    border-radius: 8px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: 12px;
                    color: #666;
                }
                .group-slot.filled { background: #2ecc71; border-color: #27ae60; color: #fff; }
            </style>
        </head>
        <body>
            <div class="game-container">
                <div class="grid" id="grid"></div>
                <div class="groups" id="groups"></div>
            </div>
            <script>
                let score = 0, best = 0, moves = 0, selectedTiles = [], matchedGroups = [];
                const gameData = [
                    { category: "Colors", words: ["RED", "BLUE", "GREEN", "YELLOW"] },
                    { category: "Animals", words: ["CAT", "DOG", "BIRD", "FISH"] },
                    { category: "Fruits", words: ["APPLE", "BANANA", "ORANGE", "GRAPE"] },
                    { category: "Sports", words: ["SOCCER", "BASKETBALL", "TENNIS", "GOLF"] }
                ];
                let allTiles = [], currentGroups = [];
                function shuffle(array) {
                    const shuffled = [...array];
                    for (let i = shuffled.length - 1; i > 0; i--) {
                        const j = Math.floor(Math.random() * (i + 1));
                        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
                    }
                    return shuffled;
                }
                function initGame() {
                    allTiles = shuffle(gameData.flatMap(g => g.words));
                    selectedTiles = []; matchedGroups = [];
                    currentGroups = gameData.map(g => ({ category: g.category, words: [], slots: 4 }));
                    moves = 0; score = 0;
                    renderGrid(); renderGroups(); updateHUD();
                }
                function renderGrid() {
                    const grid = document.getElementById('grid');
                    grid.innerHTML = '';
                    allTiles.forEach((word, index) => {
                        const tile = document.createElement('div');
                        tile.className = 'tile';
                        tile.textContent = word;
                        tile.dataset.index = index;
                        tile.dataset.word = word;
                        if (matchedGroups.some(g => g.includes(word))) {
                            tile.classList.add('matched');
                            tile.style.pointerEvents = 'none';
                        } else {
                            tile.addEventListener('click', () => selectTile(index, word));
                        }
                        grid.appendChild(tile);
                    });
                }
                function renderGroups() {
                    const groupsContainer = document.getElementById('groups');
                    groupsContainer.innerHTML = '';
                    currentGroups.forEach((group, groupIndex) => {
                        const groupDiv = document.createElement('div');
                        groupDiv.className = 'group';
                        for (let i = 0; i < 4; i++) {
                            const slot = document.createElement('div');
                            slot.className = 'group-slot';
                            if (group.words[i]) {
                                slot.textContent = group.words[i];
                                slot.classList.add('filled');
                            }
                            groupDiv.appendChild(slot);
                        }
                        groupsContainer.appendChild(groupDiv);
                    });
                }
                function selectTile(index, word) {
                    const tile = document.querySelector(`[data-index="${index}"]`);
                    if (!tile || tile.classList.contains('matched')) return;
                    if (selectedTiles.includes(index)) {
                        selectedTiles = selectedTiles.filter(i => i !== index);
                        tile.classList.remove('selected');
                    } else if (selectedTiles.length < 4) {
                        selectedTiles.push(index);
                        tile.classList.add('selected');
                        if (selectedTiles.length === 4) checkMatch();
                    }
                    updateSelection();
                }
                function updateSelection() {
                    document.querySelectorAll('.tile').forEach(tile => {
                        const index = parseInt(tile.dataset.index);
                        if (selectedTiles.includes(index) && !tile.classList.contains('matched')) {
                            tile.classList.add('selected');
                        } else if (!selectedTiles.includes(index)) {
                            tile.classList.remove('selected');
                        }
                    });
                }
                function checkMatch() {
                    moves++;
                    const selectedWords = selectedTiles.map(i => allTiles[i]);
                    const matchingGroup = gameData.find(group => {
                        const groupWords = new Set(group.words);
                        return selectedWords.every(w => groupWords.has(w)) && selectedWords.length === 4;
                    });
                    if (matchingGroup) {
                        const groupIndex = currentGroups.findIndex(g => g.category === matchingGroup.category);
                        if (groupIndex !== -1 && currentGroups[groupIndex].words.length === 0) {
                            currentGroups[groupIndex].words = [...selectedWords];
                            matchedGroups.push(...selectedWords);
                            score += 100;
                            if (score > best) best = score;
                            selectedTiles.forEach(i => {
                                const tile = document.querySelector(`[data-index="${i}"]`);
                                if (tile) {
                                    tile.classList.remove('selected');
                                    tile.classList.add('matched');
                                    tile.style.pointerEvents = 'none';
                                }
                            });
                            selectedTiles = [];
                            renderGroups();
                            updateHUD();
                            if (matchedGroups.length === 16) {
                                setTimeout(() => alert('Congratulations! You found all connections!'), 100);
                            }
                        }
                    } else {
                        setTimeout(() => {
                            selectedTiles.forEach(i => {
                                const tile = document.querySelector(`[data-index="${i}"]`);
                                if (tile) tile.classList.remove('selected');
                            });
                            selectedTiles = [];
                        }, 500);
                    }
                    updateHUD();
                }
                function updateHUD() {
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hud) {
                        window.webkit.messageHandlers.hud.postMessage({ score: score, best: best, moves: moves });
                    }
                }
                window.GameAPI = { newGame: function(seed) { initGame(); } };
                initGame();
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(htmlString, baseURL: nil)
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

