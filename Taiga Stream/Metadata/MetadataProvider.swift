//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation

protocol MetadataProvider {
	func matches(streamUrl: URL) -> Bool
	func poll(
		streamUrl: URL,
		completion: @escaping (_ artist: String, _ title: String) -> Void
	)
	var pollInterval: TimeInterval? { get }
}
