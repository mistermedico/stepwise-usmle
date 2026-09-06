import Foundation

/// The three states a board cell can be in while solving.
/// `marked` ("X") is a player memory aid, never checked against the solution.
enum CellState: String, Codable {
    case empty
    case filled
    case marked
}

/// Player-facing input gesture, decoupled from the specific tap/drag handling in the view layer.
enum MarkAction {
    case fill
    case mark
    case clear
}
