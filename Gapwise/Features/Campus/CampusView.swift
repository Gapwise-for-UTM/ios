import SwiftUI

struct CampusView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GapwiseSpacing.spacious) {
                Picker(
                    "Campus context",
                    selection: Binding(
                        get: { appModel.preferences.campusContext },
                        set: { appModel.setCampusContext($0) }
                    )
                ) {
                    ForEach(Campus.allCases) { campus in
                        Text(campus.shortName).tag(campus)
                    }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: GapwiseSpacing.compact) {
                    Text(appModel.preferences.campusContext.shortName)
                        .font(.largeTitle.weight(.bold))
                    Text(appModel.preferences.campusContext.fullName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                campusStatus(for: appModel.preferences.campusContext)
            }
            .padding(GapwiseSpacing.standard)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Campus")
    }

    @ViewBuilder
    private func campusStatus(for campus: Campus) -> some View {
        if campus == .utm {
            VStack(alignment: .leading, spacing: GapwiseSpacing.standard) {
                Label("UTM is the first campus-intelligence focus", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .foregroundStyle(.gapwiseAccent)
                Text("Map and routing will arrive after verified campus data is integrated.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .gapwiseCard()
        } else {
            ContentUnavailableView(
                "Campus Intelligence Not Available",
                systemImage: "map",
                description: Text(
                    "Timetable support remains campus-aware. The campus layer is currently focused on UTM.")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
        }
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            CampusView()
                .environment(PreviewData.appModel())
        }
    }
#endif
