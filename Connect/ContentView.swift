import SwiftUI
import WebKit

struct ContentView: View {
    @State private var score = 0
    @State private var best  = 0
    @State private var moves = 25

    // Keep the webview so we can call JS (e.g., New Game)
    @State private var webRef: WKWebView?

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

            VStack(spacing: 18) {
                Text("Connections")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    pill("Score", score)
                    pill("Best", best)
                    pill("Moves", moves)
                }

                WebGameView(onHUD: { sc, be, mv in
                    score = sc; best = be; moves = mv
                }, webRef: $webRef)
                .frame(width: 420, height: 600)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)

                Button("New Game") {
                    webRef?.evaluateJavaScript("window.GameAPI?.newGame(0);", completionHandler: nil)
                }
                .font(.headline)
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(Color.cyan)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
    }

    private func pill(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundColor(.white.opacity(0.7))
            Text("\(value)").font(.headline).monospacedDigit().foregroundColor(.white)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Color.white.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

