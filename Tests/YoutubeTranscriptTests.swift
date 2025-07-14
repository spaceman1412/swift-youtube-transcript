import Foundation
import Testing

@testable import YoutubeTranscript

// Test to verify if the API is working as expected in case the YouTube API changes in the future
struct YoutubeTranscriptTests {
  // MARK: - Success Case
  @Test func fetchTranscriptSuccess() async throws {
    let videoId = "Kbk9BiPhm7o"
    let transcript = try await YoutubeTranscript.fetchTranscript(for: videoId)
    #expect(!transcript.isEmpty)
  }

  // MARK: - Error: Invalid Video ID
  @Test func fetchTranscriptInvalidVideoId() async {
    let invalidId = "invalid"
    async #expect(throws: YoutubeTranscriptError.invalidVideoId) {
      try await YoutubeTranscript.fetchTranscript(for: invalidId)
    }
  }

  // MARK: - Error: Video Unavailable
  @Test func fetchTranscriptVideoUnavailable() async {
    let videoId = "VIDEO_ID_UNAVAILABLE"
    async #expect(throws: YoutubeTranscriptError.videoUnavailable(videoId)) {
      try await YoutubeTranscript.fetchTranscript(for: videoId)
    }
  }

  // MARK: - Error: Transcript Disabled
  @Test func fetchTranscriptDisabled() async {
    let videoId = "GK351yoTViQ"
    async #expect(throws: YoutubeTranscriptError.disabled(videoId)) {
      try await YoutubeTranscript.fetchTranscript(for: videoId)
    }
  }

  // MARK: - Error: Transcript Not Available
  @Test func fetchTranscriptNotAvailable() async {
    // TODO: Replace with a real video ID that has no transcript available
    let videoId = "VIDEO_ID_NO_TRANSCRIPT"
    async #expect(throws: YoutubeTranscriptError.notAvailable(videoId)) {
      try await YoutubeTranscript.fetchTranscript(for: videoId)
    }
  }

  // MARK: - Error: Not Available Language
  @Test func fetchTranscriptNotAvailableLanguage() async {
    let videoId = "Kbk9BiPhm7o"
    let config = TranscriptConfig(lang: "zz")  // unlikely language code
    do {
      _ = try await YoutubeTranscript.fetchTranscript(for: videoId, config: config)
    } catch let error as YoutubeTranscriptError {
      print(error)
      if case .notAvailableLanguage(_, _, let vid) = error {
        #expect(vid == videoId)
      } else {
        #expect(Bool(false))  // Should not succeed
      }
    } catch {
      #expect(Bool(false))  // Should not succeed
    }
  }

  // MARK: - Error: Empty Transcript
  @Test func fetchTranscriptEmptyTranscript() async {
    // TODO: Replace with a real video ID that has an empty transcript
    let videoId = "VIDEO_ID_EMPTY_TRANSCRIPT"
    do {
      _ = try await YoutubeTranscript.fetchTranscript(for: videoId)
    } catch let error as YoutubeTranscriptError {
      if case .emptyTranscript(let vid, _) = error {
        #expect(vid == videoId)
      } else {
        #expect(Bool(false))  // Should not succeed
      }
    } catch {
      #expect(Bool(false))  // Should not succeed
    }
  }
}
