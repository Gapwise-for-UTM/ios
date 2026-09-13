import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        TabView {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }

            NavigationStack {
                TimetableView()
            }
            .tabItem {
                Label("Timetable", systemImage: "calendar")
            }

            NavigationStack {
                CampusView()
            }
            .tabItem {
                Label("Campus", systemImage: "map")
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .tint(.gapwiseAccent)
        .alert(
            "Gapwise",
            isPresented: Binding(
                get: { appModel.alertMessage != nil },
                set: { isPresented in
                    if !isPresented { appModel.dismissAlert() }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                appModel.dismissAlert()
            }
        } message: {
            if let alertMessage = appModel.alertMessage {
                Text(alertMessage)
            }
        }
    }
}
