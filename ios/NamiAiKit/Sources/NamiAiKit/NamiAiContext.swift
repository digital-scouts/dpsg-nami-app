import Foundation

/// Loads and caches the fixed Stammesversammlung pilot context, shipped as this package's
/// own bundled resource. No retrieval, no ranking — the whole subset is used as-is (this is
/// a deliberate first spike, see specs/nami-ai-roadmap.md section 3.1). No Flutter/App
/// dependency: the resource ships inside NamiAiKit itself via Bundle.module.
enum NamiAiContext {
  private static let resourceName = "stammesversammlung_pilot_chunks"

  private static var cachedChunks: [String]?

  /// Returns the pilot chunk texts, decoding once and caching afterwards. Returns nil if
  /// the resource is missing, unreadable, or doesn't decode into a non-empty array of
  /// non-blank strings.
  static func loadChunks() -> [String]? {
    if let cached = cachedChunks {
      return cached
    }
    guard let url = Bundle.module.url(forResource: resourceName, withExtension: "json"),
      let data = try? Data(contentsOf: url)
    else {
      return nil
    }
    guard let chunks = try? JSONDecoder().decode([String].self, from: data),
      !chunks.isEmpty,
      chunks.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    else {
      return nil
    }
    cachedChunks = chunks
    return chunks
  }
}
