import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        TabView(selection: $appModel.selectedTab) {
            NavigationStack {
                TodayView()
            }
            .tabItem {
                Label("Today", systemImage: "sun.max")
            }
            .tag(AppTab.today)

            NavigationStack {
                TimetableView()
            }
            .tabItem {
                Label("Timetable", systemImage: "calendar")
            }
            .tag(AppTab.timetable)

            NavigationStack {
                GapsView()
            }
            .tabItem {
                Label("Gaps", systemImage: "hourglass")
            }
            .tag(AppTab.gaps)

            NavigationStack {
                CampusMapView()
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(AppTab.map)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
        .tint(.gapwiseAccent)
        .fileImporter(
            isPresented: $appModel.isSelectingCalendar,
            allowedContentTypes: [.gapwiseICalendar]
        ) { result in
            switch result {
            case let .success(url):
                Task { await appModel.prepareTimetableImport(from: url) }
            case let .failure(error):
                let cocoaError = error as NSError
                guard cocoaError.domain != NSCocoaErrorDomain || cocoaError.code != NSUserCancelledError else { return }
                appModel.alertMessage = "The calendar picker could not open the selected file."
            }
        }
        .sheet(
            isPresented: Binding(
                get: { appModel.pendingImportPlan != nil },
                set: { if !$0 { appModel.cancelPendingImport() } }
            )
        ) {
            if let plan = appModel.pendingImportPlan {
                TimetableImportPreviewView(plan: plan)
                    .environment(appModel)
            }
        }
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
