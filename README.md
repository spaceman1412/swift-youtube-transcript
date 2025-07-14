# YoutubeTranscript

A Swift library for fetching YouTube video transcripts (captions) programmatically. Supports both standard YouTube videos and Shorts, with robust error handling and async/await support.

## Features

- Fetches transcripts for YouTube videos and Shorts
- Supports language selection
- Handles all major YouTube transcript error cases
- Async/await API for modern Swift concurrency
- Comprehensive unit tests using Swift Testing

## Installation

Add this package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/yourusername/swift-youtube-transcript.git", from: "1.0.0")
```

And add `YoutubeTranscript` as a dependency for your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "YoutubeTranscript", package: "swift-youtube-transcript")
    ]
)
```

## Usage

```swift
import YoutubeTranscript

Task {
    do {
        let transcript = try await YoutubeTranscript.fetchTranscript(for: "YOUR_VIDEO_ID")
        for entry in transcript {
            print("\(entry.offset)s: \(entry.text)")
        }
    } catch {
        print("Failed to fetch transcript: \(error)")
    }
}
```

### Fetching in a Specific Language

```swift
let config = TranscriptConfig(lang: "en")
let transcript = try await YoutubeTranscript.fetchTranscript(for: "YOUR_VIDEO_ID", config: config)
```

## Error Handling

The library throws `YoutubeTranscriptError` for all error cases:

- `.tooManyRequests`: YouTube is rate-limiting your IP
- `.videoUnavailable`: The video is not available
- `.disabled`: Transcripts are disabled for this video
- `.notAvailable`: No transcripts are available
- `.notAvailableLanguage`: No transcript in the requested language
- `.emptyTranscript`: The transcript is empty
- `.invalidVideoId`: The video ID is invalid
- `.networkError`: Network error occurred
- `.parsingError`: Failed to parse YouTube response

## Testing

This project uses [Swift Testing](https://github.com/apple/swift-testing) for its test suite.

To run the tests:

```sh
swift test
```

The tests cover all major success and error cases for `fetchTranscript`. You can provide your own video IDs in `Tests/YoutubeTranscriptTests.swift` to verify real-world scenarios.

## License

MIT
