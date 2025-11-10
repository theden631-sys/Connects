import SwiftUI
import WebKit

struct ContentView: View {
    @State private var best  = 0

    // Keep the webview so we can call JS (e.g., New Game)
    @State private var webRef: WKWebView?
    
    // UserDefaults key for high score
    private let highScoreKey = "bestScore"
    
    // Load high score from UserDefaults
    private func loadHighScore() -> Int {
        UserDefaults.standard.integer(forKey: highScoreKey)
    }
    
    // Save high score to UserDefaults
    private func saveHighScore(_ score: Int) {
        UserDefaults.standard.set(score, forKey: highScoreKey)
    }

    var body: some View {
        ZStack {
            // Match game background: gradient from #0e2a47 to #1b2f66
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 14/255.0, green: 42/255.0, blue: 71/255.0),  // #0e2a47
                    Color(red: 27/255.0, green: 47/255.0, blue: 102/255.0)  // #1b2f66
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Connections")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                WebGameView(onHUD: { sc, be, mv in
                    // Always use the maximum of game's best and saved high score
                    let savedHighScore = loadHighScore()
                    let newBest = max(be, max(sc, savedHighScore))
                    if newBest > savedHighScore {
                        saveHighScore(newBest)
                    }
                    best = newBest
                }, initialBest: best, webRef: $webRef)
                .frame(width: 420, height: 600)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
            }
            .padding()
        }
        .onAppear {
            // Load saved high score when view appears
            best = loadHighScore()
        }
    }

}

