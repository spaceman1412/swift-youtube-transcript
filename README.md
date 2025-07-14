# YoutubeTranscript

I tried to find a library that fetches YouTube video transcripts for Swift but couldn’t find one, so I made one myself.

This package uses an unofficial YouTube API, so it may break over time if no updates are made.
The library uses an HTML scraper and the Innertube API to fetch transcripts.

Heavily inspired by [youtube-transcript](https://github.com/Kakulukian/youtube-transcript)

## Table of Contents

- [Features](#features)
- [Usage](#usage)
  - [Example](#example)
  - [Fetching in a Specific Language](#fetching-in-a-specific-language)
  - [Supported URL Formats](#supported-url-formats)
  - [Error Handling](#error-handling)
- [Minimum requirements](#minimum-requirements)
- [Installation](#installation)
  - [Adding YoutubeTranscript to a Swift package](#adding-youtubetranscript-to-a-swift-package)
  - [Adding YoutubeTranscript to an Xcode project](#adding-youtubetranscript-to-an-xcode-project)
- [Testing](#testing)
- [License](#license)

## Features

- Fetches transcripts for YouTube videos and Shorts
- Supports language selection
- Handles all major YouTube transcript error cases
- Async/await API for modern Swift concurrency
- Comprehensive unit tests using Swift Testing

## Usage

Library using one simple function to fetch transcript

```swift
fetchTranscript(for videoId: String,config: TranscriptConfig = .init()) async throws -> [TranscriptResponse]
```

### Example

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

### Supported URL Formats

- Standard videos: `https://www.youtube.com/watch?v=VIDEO_ID`
- Short URLs: `https://youtu.be/VIDEO_ID`
- YouTube Shorts: `https://www.youtube.com/shorts/VIDEO_ID`
- Embedded videos: `https://www.youtube.com/embed/VIDEO_ID`
- Direct video IDs: `VIDEO_ID`

### Error Handling

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

## Minimum requirements

- macOS 12.0+
- iOS 15.0+
- tvOS 15.0+
- watchOS 8.0+

## Installation

### Adding YoutubeTranscript to a Swift package

Add this package to your `Package.swift` dependencies:

```swift
.package(url: "https://github.com/spaceman1412/swift-youtube-transcript.git", from: "1.0.0")
```

And add `YoutubeTranscript` as a dependency for your target:

```swift
.target(
    name: "<target>",
    dependencies: [
        .product(name: "YoutubeTranscript", package: "swift-youtube-transcript")
    ]
)
```

### Adding YoutubeTranscript to an Xcode project

1. From the **File** menu, select **Add Packages…**
1. Enter `https://github.com/spaceman1412/swift-youtube-transcript` into the
   _Search or Enter Package URL_ search field
1. Link **YoutubeTranscript** to your application target

## Testing

This project uses [Swift Testing](https://github.com/apple/swift-testing) for its test suite.

To run the tests:

```sh
swift test
```

The tests cover all major success and error cases for `fetchTranscript`. You can provide your own video IDs in `Tests/YoutubeTranscriptTests.swift` to verify real-world scenarios.

## License

MIT
