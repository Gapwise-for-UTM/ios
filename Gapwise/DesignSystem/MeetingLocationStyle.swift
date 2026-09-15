extension MeetingLocation {
    var systemImageName: String {
        switch kind {
        case .physical: "mappin"
        case .online: "video"
        case .toBeAnnounced: "questionmark.circle"
        case .unknown: "mappin.slash"
        }
    }
}
