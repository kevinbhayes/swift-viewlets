//
//  RelativeStackTypes.swift
//  SwiftViewlets
//
//  Created by Kevin Hayes on 2025-05-10.
//

import SwiftUI

/// Cache used by RelativeStacks to store sizing and layout information
///
/// This should never need to be created manually.
public class RelativeCacheInfo {
	/// the multiplier to be used on views that aren’t Spacers and are not views with relativeStackPortion applied
	var nonRelativeMultiplier: CGFloat = 1.0
	/// the length each Spacer (if the view contains Spacers) should be
	var spacerLength: CGFloat = 0.0
	/// information about each subview
	var subviewInfo: [SubviewInfo]
	/// we need to store the furthest offset applied when aligning the views, to bring the view back within bounds
	var maxAlignmentOffset: CGFloat = 0.0
	/// the total length of the view (height in VStack, width in HStack) not including
	/// spacing between views
	var totalLength: CGFloat = 0.0

	init() {
		subviewInfo = []
	}

	struct SubviewInfo {
		/// the length of the subview (height in VStack, width in HStack)
		let length: CGFloat
		/// the type of subview
		var type: SubviewType
		/// the offset based on the provided alignment in the layout
		let alignmentOffset: CGFloat

		/// update the type of the subview
		mutating func updateType(_ type: SubviewType) {
			self.type = type
		}
	}

	enum SubviewType {
		/// a subview with relativeStackPortion applied
		case relative
		/// a subview without relativeHLayoutHeight applied
		/// and whether not the view can grow (e.g. Text usually cannot
		/// grow, while Color can)
		case regular(canGrow: Bool)
		/// the subview is a Spacer
		case spacer
	}
}

struct RelativePortionKey: LayoutValueKey {
	static let defaultValue: Double? = nil
}

public extension View {
	/// Specifies the retalive portion to occupy inside a RelativeStack
	/// - Parameter multiplier: the portion of the stack to occupy.
	/// Valid values are between 0.0 and 1.0, non-inclusively
	func relativeStackPortion(_ multiplier: Double?) -> some View {
		layoutValue(key: RelativePortionKey.self, value: multiplier)
	}
}
