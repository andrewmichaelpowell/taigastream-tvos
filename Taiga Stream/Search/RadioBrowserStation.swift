//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

struct RadioBrowserStation: Identifiable {
	let id: String
	let name: String
	let url: String
	let faviconUrl: String
	let country: String
	let state: String
	let language: String
	let tags: String
	let votes: Int
	let bitrate: Int
}
