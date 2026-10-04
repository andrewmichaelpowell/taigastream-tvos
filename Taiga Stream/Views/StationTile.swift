//  Taiga Stream (tvOS)
//  github.com/andrewmichaelpowell

import Foundation
import SwiftUI

struct StationTile: View {
	let index: Int
	@Binding var movingIndex: Int?
	@EnvironmentObject var streamInfo: StreamInfo
	@State private var showingOptions = false
	@State private var didLongPress = false
	@State private var showingManualEntry = false
	@State private var showingSearch = false
	@State private var manualUrl = ""
	@State private var manualName = ""

	var station: RadioStation { streamInfo.stations[index] }

	private var streamNumber: Int { index + 1 }

	private var isPlaying: Bool {
		streamInfo.isPlaying && streamInfo.currentStream == streamNumber
			&& !station.url.isEmpty
	}

	private var isMoving: Bool { movingIndex == index }

	var body: some View {
		Button(action: select) {
			Color.clear
				.aspectRatio(1, contentMode: .fit)
				.overlay {
					if station.url.isEmpty {
						emptyContent
					} else {
						configuredContent
					}
				}
		}
		.buttonStyle(.card)
		.simultaneousGesture(
			LongPressGesture(minimumDuration: 0.5).onEnded { _ in
				didLongPress = true
				showingOptions = true
			}
		)
		.sheet(isPresented: $showingOptions) {
			StreamOptionsSheet(
				index: index,
				isPresented: $showingOptions,
				showingSearch: $showingSearch,
				showingManualEntry: $showingManualEntry,
				manualUrl: $manualUrl,
				manualName: $manualName,
				movingIndex: $movingIndex
			)
			.environmentObject(streamInfo)
		}
		.onChange(of: showingOptions) {
			if !showingOptions { didLongPress = false }
		}
		.sheet(isPresented: $showingSearch) {
			RadioBrowserSearchSheet(
				slotIndex: index,
				isPresented: $showingSearch
			)
			.environmentObject(streamInfo)
		}
		.sheet(isPresented: $showingManualEntry) {
			ManualURLSheet(
				slotIndex: index,
				isPresented: $showingManualEntry,
				manualUrl: $manualUrl,
				manualName: $manualName
			)
			.environmentObject(streamInfo)
		}
	}

	private var emptyContent: some View {
		VStack(spacing: 20) {
			FaviconView(station: station, size: 120)
			HStack {
				statusLabel
				Spacer()
			}
			.font(.callout)
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(isMoving ? Color.mint.opacity(0.35) : Color.clear)
	}

	private var configuredContent: some View {
		GeometryReader { geometry in
			FaviconView(
				station: station,
				size: geometry.size.width,
				cornerRadius: 0
			)
		}
		.overlay(alignment: .bottomLeading) {
			statusLabel
				.font(.callout)
				.frame(width: 56, height: 56)
				.background(Circle().fill(isMoving ? Color.mint : Color.slot))
				.padding(12)
		}
	}

	@ViewBuilder
	private var statusLabel: some View {
		if isMoving {
			Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
				.foregroundColor(station.url.isEmpty ? .mint : Color(.label))
		} else if isPlaying {
			Image(systemName: "stop.fill")
				.foregroundColor(.mint)
		} else {
			Text("\(streamNumber)")
				.foregroundColor(
					station.url.isEmpty
						? Color(.quaternaryLabel) : Color(.label)
				)
		}
	}

	private func select() {
		if didLongPress {
			didLongPress = false
		} else if isMoving {
			movingIndex = nil
		} else if station.url.isEmpty {
			showingOptions = true
		} else {
			Task { await PlayStream.shared.play(streamNumber: streamNumber) }
		}
	}
}
