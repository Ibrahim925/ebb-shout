enum PipelineStage: Equatable {
    case idle
    case recording
    case transcribing
    case enhancing
    case done
    case error(String)

    var isActive: Bool { self != .idle }

    static func == (lhs: PipelineStage, rhs: PipelineStage) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording), (.transcribing, .transcribing),
             (.enhancing, .enhancing), (.done, .done): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
