//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

enum PodcastFeedError: Error {
	case invalidFeed
}

/// Parses an RSS podcast feed into a channel title, artwork and its audio
/// episodes, newest first.
nonisolated final class PodcastFeedParser: NSObject, XMLParserDelegate {
	private var channelTitle = ""
	private var channelArtwork = ""
	private var episodes: [PodcastEpisode] = []

	private var inItem = false
	private var inImage = false
	private var text = ""
	private var itemTitle = ""
	private var itemGuid = ""
	private var itemAudioUrl = ""
	private var itemAudioType = ""
	private var itemPubDate = ""
	private var itemDuration = ""
	private var itemArtwork = ""
	private var sawRSS = false

	static func fetch(_ urlString: String) async throws -> PodcastFeed {
		guard let url = URL(string: urlString) else {
			throw PodcastFeedError.invalidFeed
		}
		var request = URLRequest(
			url: url,
			cachePolicy: .reloadIgnoringLocalCacheData,
			timeoutInterval: 20
		)
		request.setValue("Taiga Stream", forHTTPHeaderField: "User-Agent")
		let (data, _) = try await URLSession.shared.data(for: request)
		return try await Task.detached(priority: .userInitiated) {
			try parse(data)
		}.value
	}

	static func parse(_ data: Data) throws -> PodcastFeed {
		let delegate = PodcastFeedParser()
		let parser = XMLParser(data: data)
		parser.shouldProcessNamespaces = false
		parser.delegate = delegate
		guard parser.parse() || !delegate.episodes.isEmpty, delegate.sawRSS
		else { throw PodcastFeedError.invalidFeed }
		let sorted = delegate.episodes.enumerated().sorted { a, b in
			switch (a.element.publishedAt, b.element.publishedAt) {
			case let (lhs?, rhs?) where lhs != rhs: return lhs > rhs
			default: return a.offset < b.offset
			}
		}.map(\.element)
		return PodcastFeed(
			title: delegate.channelTitle.trimmingCharacters(
				in: .whitespacesAndNewlines
			),
			artworkUrl: delegate.channelArtwork,
			episodes: sorted
		)
	}

	func parser(
		_ parser: XMLParser,
		didStartElement elementName: String,
		namespaceURI: String?,
		qualifiedName qName: String?,
		attributes: [String: String] = [:]
	) {
		text = ""
		switch elementName {
		case "rss", "channel":
			sawRSS = true
		case "item":
			inItem = true
			itemTitle = ""
			itemGuid = ""
			itemAudioUrl = ""
			itemAudioType = ""
			itemPubDate = ""
			itemDuration = ""
			itemArtwork = ""
		case "image" where !inItem:
			inImage = true
		case "itunes:image":
			let href = attributes["href"] ?? ""
			if inItem {
				itemArtwork = href
			} else if !href.isEmpty {
				channelArtwork = href
			}
		case "enclosure" where inItem:
			let type = (attributes["type"] ?? "").lowercased()
			let url = attributes["url"] ?? ""
			let isAudio = type.isEmpty || type.hasPrefix("audio")
			if !url.isEmpty, itemAudioUrl.isEmpty || (isAudio && !itemAudioType.hasPrefix("audio")) {
				itemAudioUrl = url
				itemAudioType = type
			}
		default:
			break
		}
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		text += string
	}

	func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
		text += String(decoding: CDATABlock, as: UTF8.self)
	}

	func parser(
		_ parser: XMLParser,
		didEndElement elementName: String,
		namespaceURI: String?,
		qualifiedName qName: String?
	) {
		let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
		switch elementName {
		case "title":
			if inItem {
				itemTitle = value
			} else if !inImage && channelTitle.isEmpty {
				channelTitle = value
			}
		case "url" where inImage && channelArtwork.isEmpty:
			channelArtwork = value
		case "image":
			inImage = false
		case "guid" where inItem:
			itemGuid = value
		case "pubDate" where inItem:
			itemPubDate = value
		case "itunes:duration" where inItem:
			itemDuration = value
		case "item":
			inItem = false
			guard !itemAudioUrl.isEmpty else { break }
			episodes.append(
				PodcastEpisode(
					id: itemGuid.isEmpty ? itemAudioUrl : itemGuid,
					title: itemTitle,
					audioUrl: itemAudioUrl,
					publishedAt: Self.parseDate(itemPubDate),
					duration: Self.parseDuration(itemDuration),
					artworkUrl: itemArtwork.isEmpty ? nil : itemArtwork
				)
			)
		default:
			break
		}
		text = ""
	}

	private static let dateFormatters: [DateFormatter] = [
		"EEE, d MMM yyyy HH:mm:ss Z",
		"EEE, d MMM yyyy HH:mm:ss zzz",
		"EEE, d MMM yyyy HH:mm Z",
		"d MMM yyyy HH:mm:ss Z",
		"EEE, d MMM yyyy",
		"yyyy-MM-dd'T'HH:mm:ssZ",
	].map { format in
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.dateFormat = format
		return formatter
	}

	static func parseDate(_ value: String) -> Date? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		for formatter in dateFormatters {
			if let date = formatter.date(from: trimmed) { return date }
		}
		return nil
	}

	static func parseDuration(_ value: String) -> Double? {
		let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return nil }
		let parts = trimmed.split(separator: ":").compactMap { Double($0) }
		guard !parts.isEmpty, parts.count <= 3 else { return nil }
		let seconds = parts.reduce(0) { $0 * 60 + $1 }
		return seconds > 0 ? seconds : nil
	}
}
