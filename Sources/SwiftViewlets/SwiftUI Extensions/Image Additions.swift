//
//  Image Additions.swift
//  SwiftViewlets
//
//  Created by Kevin Hayes on 2025-05-16.
//

import SwiftUI

extension Image {
	/// Initializes an Image view from provided data. If an image cannot be created from
	/// the data, an empty image will be returned.
	///
	/// On macOS, see the documentation for
	/// `NSImage.init?(data: Data)`. On other operating systems, see `UIImage.init?(data: Data)`.
	///
	/// - Parameter data: data that can be used to create an image.
	init(data: Data) {
#if os(macOS)
		if let nsImage = NSImage(data: data) {
			self.init(nsImage: nsImage)
		}
		else {
			self.init(decorative: "")
		}
#else
		if let uiImage = UIImage(data: data) {
			self.init(uiImage: uiImage)
		}
		else {
			self.init(decorative: "")
		}
#endif
	}
}
