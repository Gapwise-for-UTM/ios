/// Native integration availability, supplied by app composition.
/// A future adapter must consume pinned Gapwise Data identities/evidence and canonical
/// Gapwise routing contracts. Imported room text never establishes a coordinate,
/// entrance, accessibility claim, or route. See docs/architecture.md.
enum UTMCampusIntegration: Sendable {
    case notIntegrated
}
