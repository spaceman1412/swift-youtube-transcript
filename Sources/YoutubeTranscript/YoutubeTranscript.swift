import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

public struct TranscriptResponse: Codable, Equatable, Sendable {
  public let text: String
  public let duration: Double
  public let offset: Double
  public let lang: String?
}

public struct TranscriptConfig: Sendable {
  public let lang: String?
  public init(lang: String? = nil) {
    self.lang = lang
  }
}

// MARK: - Errors
public enum YoutubeTranscriptError: Error, LocalizedError, Equatable {
  case tooManyRequests
  case videoUnavailable(String)
  case disabled(String)
  case notAvailable(String)
  case notAvailableLanguage(lang: String, availableLangs: [String], videoId: String)
  case emptyTranscript(videoId: String, method: String)
  case invalidVideoId
  case networkError(String)
  case parsingError(String)

  public var errorDescription: String? {
    switch self {
    case .tooManyRequests:
      return
        "[YoutubeTranscript] 🚨 YouTube is receiving too many requests from this IP and now requires solving a captcha to continue"
    case .videoUnavailable(let videoId):
      return "[YoutubeTranscript] 🚨 The video is no longer available (\(videoId))"
    case .disabled(let videoId):
      return "[YoutubeTranscript] 🚨 Transcript is disabled on this video (\(videoId))"
    case .notAvailable(let videoId):
      return "[YoutubeTranscript] 🚨 No transcripts are available for this video (\(videoId))"
    case .notAvailableLanguage(let lang, let availableLangs, let videoId):
      return
        "[YoutubeTranscript] 🚨 No transcripts are available in \(lang) for this video (\(videoId)). Available languages: \(availableLangs.joined(separator: ", "))"
    case .emptyTranscript(let videoId, let method):
      return
        "[YoutubeTranscript] 🚨 The transcript file URL returns an empty response using \(method) (\(videoId))"
    case .invalidVideoId:
      return "[YoutubeTranscript] 🚨 Impossible to retrieve Youtube video ID."
    case .networkError(let error):
      return "[YoutubeTranscript] 🚨 Network error: \(error)"
    case .parsingError(let message):
      return "[YoutubeTranscript] 🚨 Parsing error: \(message)"
    }
  }
}

// MARK: - YoutubeTranscript Main Class
public enum YoutubeTranscript {

  private static let userAgent =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/85.0.4183.83 Safari/537.36,gzip(gfe)"

  public static func fetchTranscript(for videoId: String, config: TranscriptConfig = .init())
    async throws -> [TranscriptResponse]
  {
    // The `videoId` parameter can be a full YouTube URL or just the 11-character video ID.
    // The `retrieveVideoId` helper function will handle extracting the ID from a URL.
    do {
      // First, attempt to fetch the transcript by scraping the video's HTML page.
      return try await fetchTranscriptWithHtmlScraping(videoId: videoId, config: config)
    } catch let error as YoutubeTranscriptError {
      // If the HTML scraping method returns an empty transcript, we fall back to the InnerTube API.
      if case .emptyTranscript = error {
        return try await fetchTranscriptWithInnerTube(videoId: videoId, config: config)
      }
      // For any other specific transcript error, re-throw it.
      throw error
    }
  }

  // MARK: - Private Helper Methods

  private static func fetchTranscriptWithHtmlScraping(videoId: String, config: TranscriptConfig)
    async throws -> [TranscriptResponse]
  {
    let identifier = try retrieveVideoId(from: videoId)
    guard let url = URL(string: "https://www.youtube.com/watch?v=\(identifier)") else {
      throw YoutubeTranscriptError.invalidVideoId
    }

    var request = URLRequest(url: url)
    if let lang = config.lang {
      request.setValue(lang, forHTTPHeaderField: "Accept-Language")
    }
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    let (data, _) = try await URLSession.shared.data(for: request)
    guard let html = String(data: data, encoding: .utf8) else {
      throw YoutubeTranscriptError.parsingError("Failed to decode HTML response")
    }

    if html.contains("class=\"g-recaptcha\"") {
      throw YoutubeTranscriptError.tooManyRequests
    }

    if !html.contains("\"playabilityStatus\":") {
      throw YoutubeTranscriptError.videoUnavailable(videoId)
    }

    let splittedHtml = html.components(separatedBy: "\"captions\":")

    guard splittedHtml.count > 1 else {
      throw YoutubeTranscriptError.disabled(videoId)
    }

    let captionsJsonString = splittedHtml[1].components(separatedBy: ",\"videoDetails")[0]

    guard let captionsData = captionsJsonString.data(using: .utf8) else {
      throw YoutubeTranscriptError.parsingError("Could not get captions data.")
    }

    do {
      let decoder = JSONDecoder()
      let captionsContainer = try decoder.decode(CaptionsContainer.self, from: captionsData)
      let captions = captionsContainer.playerCaptionsTracklistRenderer
      let processedTranscript: [TranscriptResponse] = try await processTranscriptFromCaptions(
        captions: captions, videoId: videoId, config: config)

      if processedTranscript.isEmpty {
        throw YoutubeTranscriptError.emptyTranscript(videoId: videoId, method: "HTML scraping")
      }
      return processedTranscript
    } catch let error as YoutubeTranscriptError {
      throw error
    } catch {
      throw YoutubeTranscriptError.parsingError(
        "Failed to parse captions JSON: \(error.localizedDescription)")
    }
  }

  private static func fetchTranscriptWithInnerTube(videoId: String, config: TranscriptConfig)
    async throws -> [TranscriptResponse]
  {
    let identifier = try retrieveVideoId(from: videoId)
    guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player") else {
      throw YoutubeTranscriptError.invalidVideoId
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    if let lang = config.lang {
      request.setValue(lang, forHTTPHeaderField: "Accept-Language")
    }
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
    request.setValue("https://www.youtube.com/watch?v=\(identifier)", forHTTPHeaderField: "Referer")

    let body: [String: Any] = [
      "context": [
        "client": [
          "clientName": "WEB",
          "clientVersion": "2.20250312.04.00",
          "userAgent": userAgent,
        ]
      ],
      "videoId": identifier,
    ]

    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    let (data, _) = try await URLSession.shared.data(for: request)

    do {
      let decoder = JSONDecoder()
      let response = try decoder.decode(InnerTubeResponse.self, from: data)

      guard let captions = response.captions?.playerCaptionsTracklistRenderer else {
        throw YoutubeTranscriptError.disabled(videoId)
      }

      let processedTranscript = try await processTranscriptFromCaptions(
        captions: captions, videoId: videoId, config: config)

      if processedTranscript.isEmpty {
        throw YoutubeTranscriptError.emptyTranscript(videoId: videoId, method: "InnerTube API")
      }
      return processedTranscript
    } catch let error as YoutubeTranscriptError {
      throw error
    } catch {
      throw YoutubeTranscriptError.parsingError(
        "Failed to parse captions JSON: \(error.localizedDescription)")
    }
  }

  private static func processTranscriptFromCaptions(
    captions: PlayerCaptionsTracklistRenderer, videoId: String, config: TranscriptConfig
  ) async throws -> [TranscriptResponse] {
    let tracks = captions.captionTracks
    if tracks.isEmpty {
      throw YoutubeTranscriptError.notAvailable(videoId)
    }

    var track = tracks[0]
    if let lang = config.lang {
      guard let langTrack = tracks.first(where: { $0.languageCode == lang }) else {
        let availableLangs = tracks.map { $0.languageCode }
        throw YoutubeTranscriptError.notAvailableLanguage(
          lang: lang, availableLangs: availableLangs, videoId: videoId)
      }
      track = langTrack
    }

    var request = URLRequest(url: track.baseUrl)
    if let lang = config.lang {
      request.setValue(lang, forHTTPHeaderField: "Accept-Language")
    }
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw YoutubeTranscriptError.notAvailable(videoId)
    }

    guard let xmlString = String(data: data, encoding: .utf8) else {
      throw YoutubeTranscriptError.parsingError("Failed to decode XML transcript")
    }

    let regex = try! NSRegularExpression(
      pattern: "<text start=\"([^\"]*)\" dur=\"([^\"]*)\">([^<]*)<\\/text>")
    let range = NSRange(xmlString.startIndex..., in: xmlString)
    let matches = regex.matches(in: xmlString, range: range)

    return matches.map { match in
      let textRange = match.range(at: 3)
      let durationRange = match.range(at: 2)
      let offsetRange = match.range(at: 1)

      let text = (xmlString as NSString).substring(with: textRange)
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")

      let durationStr = (xmlString as NSString).substring(with: durationRange)
      let offsetStr = (xmlString as NSString).substring(with: offsetRange)

      return TranscriptResponse(
        text: text,
        duration: Double(durationStr) ?? 0.0,
        offset: Double(offsetStr) ?? 0.0,
        lang: config.lang ?? track.languageCode
      )
    }
  }

  private static func retrieveVideoId(from string: String) throws -> String {
    if string.count == 11 {
      return string
    }
    let regex = try! NSRegularExpression(
      pattern:
        "(?:youtube\\.com\\/(?:[^\\/]+\\/.+\\/|(?:v|e(?:mbed)?|shorts)\\/|.*[?&]v=)|youtu\\.be\\/)([^\"&?\\/\\s]{11})",
      options: .caseInsensitive
    )
    let range = NSRange(string.startIndex..., in: string)
    if let match = regex.firstMatch(in: string, range: range) {
      if let videoIdRange = Range(match.range(at: 1), in: string) {
        return String(string[videoIdRange])
      }
    }
    throw YoutubeTranscriptError.invalidVideoId
  }
}

// MARK: - Internal Helper Structs
private struct CaptionTrack: Codable {
  let baseUrl: URL
  let languageCode: String
}

private struct PlayerCaptionsTracklistRenderer: Codable {
  let captionTracks: [CaptionTrack]
}

private struct CaptionsContainer: Codable {
  let playerCaptionsTracklistRenderer: PlayerCaptionsTracklistRenderer
}

private struct InnerTubeResponse: Codable {
  let captions: CaptionsContainer?
}
