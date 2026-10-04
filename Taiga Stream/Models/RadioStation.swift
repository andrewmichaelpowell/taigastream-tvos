//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct RadioStation: Codable, Equatable, Identifiable {
	let id: UUID
	var url: String
	var name: String
	var faviconUrl: String

	init(id: UUID = UUID(), url: String, name: String, faviconUrl: String) {
		self.id = id
		self.url = url
		self.name = name
		self.faviconUrl = faviconUrl
	}

	static let empty = RadioStation(url: "", name: "", faviconUrl: "")
}
