import SwiftUI

@main
struct WBApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.80, green: 0.07, blue: 0.67),
                    Color(red: 0.45, green: 0.06, blue: 0.52),
                    Color(red: 0.25, green: 0.04, blue: 0.38)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("WB")
                    .font(.system(size: 86, weight: .black, design: .rounded))
                    .tracking(-2)
                    .foregroundColor(.white)

                Text("wildberries")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundColor(.white.opacity(0.92))
            }
        }
        .statusBarHidden(true)
    }
}
