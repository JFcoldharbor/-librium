import Foundation

enum VoiceState: Equatable {
    case idle
    case listening
    case processing
    case speaking(response: String)
    case error(message: String)
}
