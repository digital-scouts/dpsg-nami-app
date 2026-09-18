import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Keyed store of held chat sessions (specs/nami-ai-roadmap.md section 3.7). An actor because
  /// the Flutter bridge dispatches calls onto it from its own queue. Keying sessions by an
  /// opaque ID instead of holding a single implicit session guards against races from screen
  /// navigation or a Flutter hot-restart artifact — the UI only ever has one chat screen open at
  /// a time, this isn't meant to enable real concurrent chats.
  @available(iOS 26.0, macOS 26.0, *)
  actor NamiAiChatSessionStore {
    private var sessions: [String: NamiAiChatSession] = [:]

    func startSession() -> String {
      let id = UUID().uuidString
      sessions[id] = NamiAiChatSession(id: id)
      return id
    }

    func session(for id: String) -> NamiAiChatSession? {
      sessions[id]
    }

    /// Best-effort cleanup; a missing id (already ended, or never existed after an app restart)
    /// is not an error.
    func endSession(_ id: String) {
      sessions.removeValue(forKey: id)
    }
  }
#endif
