import SwiftUI

@main
struct AvocadoToastApp: App {
    @StateObject private var player = PlayerStore()
    var body: some Scene {
        WindowGroup {
            RootTabView().environmentObject(player).preferredColorScheme(.dark)
        }
    }
}