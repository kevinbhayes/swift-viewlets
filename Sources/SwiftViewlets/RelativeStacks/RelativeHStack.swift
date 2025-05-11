//
//  RelativeHStack.swift
//  SwiftViewlets
//
//  Created by Kevin Hayes on 2025-05-10.
//

import SwiftUI

/// A View Stack that arranges views in a horizontal line and allows
/// views to specify what portion of the stack to occupy.
///
/// Views can specify the portion of the stack they wish to occupy using the
/// `.relativeStackPortion(_:)` modifier that supplies a Double between 0 and 1.
/// Views that are unable to grow (e.g. a Text) will ignore this value.
///
/// The supplied relative widths across all views combined with the minimum
/// widths of the total views and the provided spacer may result in a the view
/// drawing below its bottom boundary if the Stack has a fixed frame that is
/// not wide enough to handle the supplied views and parameters.
///
/// Example usage:
/// ```
/// 	RelativeHStack(alignment: .center, spacing: 1.0) {
///			Color.green
///			  .relativeStackPortion(0.3)
///			  .frame(height: 50)
///		  	Color.yellow
///			  .frame(height: 250)
///		  	Color.orange
///		  	Color.red
///		  	Color.purple
///			  .frame(height: 250)
///		  	Color.blue
///			  .frame(height: 200)
///			  .relativeStackPortion(0.15)
///  	}
///  	.frame(height: 300, width: 300)
/// ```
public struct RelativeHStack: Layout {
	/// Creates an instance with the given spacing and vertical alignment.
	/// - Parameter alignment: The guide for aligning the subviews in this stack.
	init(alignment: VerticalAlignment = .top, spacing: CGFloat = 0.0) {
		self.alignment = alignment
		self.spacing = spacing
	}


	let alignment: VerticalAlignment
	let spacing: CGFloat

	public func makeCache(subviews: Subviews) -> RelativeCacheInfo {
		RelativeCacheInfo()
	}

	public static var layoutProperties: LayoutProperties {
		var properties = LayoutProperties()
		properties.stackOrientation = .vertical
		return properties
	}

	public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout RelativeCacheInfo) -> CGSize {
		let totalSpacing = spacing * CGFloat(subviews.count - 1)
		let height = proposal.height ?? .zero
		// if the width is not provided, get the minimum widths of the subviews
		// we detect a Spacer() based on a height of 0.0. Which probably isn’t
		// perfect, but a 0-height view draws nothing so it’s a fairly safe assumptions
		// similar views like Color have non-zero minimum heights
		let width = proposal.width ?? (subviews.reduce(.zero) { result, subview in
			let dimension = subview.dimensions(in: .unspecified)
			let infiniteDimension = subview.dimensions(in: .infinity)
			return result + ((dimension.height == 0 && infiniteDimension.height == 0) ? 0.0 : dimension.width)
		} + totalSpacing)

		// to calculate the widest view to return
		var maxHeight: CGFloat = .zero
		updateCache(&cache, subviews: subviews)

		// total widths of views that have relativeStackPortion applied
		var totalRelativeWidth: CGFloat = .zero
		// total of all relativeStackPortion values
		var totalMultiplier: CGFloat = .zero
		// count of views that do not have relativeStackPortion applied and
		// have been determined to not be Spacer
		var countNonRelativeViews: Int = .zero
		// total width of views that do not have relativeStackPortion applied
		// and have been determined to not be spacers
		var totalNonRelativeWidth: CGFloat = .zero
		// the count of all Spacers()
		var countSpacers: Int = .zero
		// for alignment purposes, calculate the maximum offset of the x coordinate
		var maxXOffset: CGFloat = .zero

		// width of the view minus the spacing values as they are fixed
		let nonSpacingWidth = width - totalSpacing

		for subview in subviews {
			// find the minimum and maximum heights of the views for determining
			// the overall height of the view to return
			let subviewSize = subview.dimensions(in: .unspecified)
			let subviewSizeInfinity = subview.dimensions(in: .infinity)
			// if it can grow, then we want it to grow to the proposed height of the container
			maxHeight = max(maxHeight, min(subviewSizeInfinity.height, height))

			// for vertical alignment
			let xOffset = subview.dimensions(in: proposal)[alignment]
			maxXOffset = max(maxXOffset, xOffset)

			// we have a view with relativeStackPortion applied
			if let relativeWidthMultiplier = subview[RelativePortionKey.self] {
				totalMultiplier += min(relativeWidthMultiplier, 1.0)
				totalRelativeWidth += subviewSize.width
				cache.subviewInfo.append(RelativeCacheInfo.SubviewInfo(length: width * relativeWidthMultiplier, type: .relative, alignmentOffset: xOffset))
			}
			else {
				// check for Spacer views
				if subviewSize.height == 0,
				   subview.dimensions(in: .infinity).height == 0 {
					// we likely have a spacer or spacer-like view
					countSpacers += 1
					cache.subviewInfo.append(RelativeCacheInfo.SubviewInfo(length: subviewSize.width, type: .spacer, alignmentOffset: xOffset))
				}
				else {
					// view that is not a Spacer and has not have relativeStackPortion applied
					countNonRelativeViews += 1
					totalNonRelativeWidth += subviewSize.width
					cache.subviewInfo.append(RelativeCacheInfo.SubviewInfo(length: subviewSize.width, type: .regular(canGrow: true), alignmentOffset: xOffset))
				}
			}
		}

		// total portion of the view width that has a relativeStackPortion applied
		let totalMultipliedWidth = totalMultiplier * width
		let remainingWidth = nonSpacingWidth - totalMultipliedWidth

		// we're at the full width of the view but no non-relative multiplied views
		// so we must report a larger size back to SwiftUI
		if totalMultipliedWidth == nonSpacingWidth,
		   countNonRelativeViews == 0 {
			cache.spacerLength = 0.0
			cache.totalLength = totalMultipliedWidth + totalNonRelativeWidth
			return CGSize(width: totalMultipliedWidth + totalNonRelativeWidth + totalSpacing, height: maxHeight)
		}

		// views with relative width multipliers exceed the width
		// so we must report a larger width back to SwiftUI
		guard remainingWidth > 0 else {
			cache.spacerLength = 0.0
			cache.totalLength = totalMultipliedWidth + totalNonRelativeWidth
			return CGSize(width: totalMultipliedWidth + totalNonRelativeWidth + totalSpacing, height: maxHeight)
		}

		// we’ve got room, so we’ll continue

		var totalFixedWidthRegular: CGFloat = .zero

		if countSpacers > 0 {
			// if we have Spacer views, their width is a split of the remaining
			// width in the proposed space
			cache.spacerLength = (remainingWidth - totalNonRelativeWidth) / CGFloat(countSpacers)
		}
		else {
			// no spacers, so we have to grow the views that don't have
			// relativeStackPortion applied, if they can grow
			for (index, subview) in subviews.enumerated() {
				if case .regular(_) = cache.subviewInfo[index].type {
					// figure out which can grow
					let subviewInfo = cache.subviewInfo[index]
					let width = subview.sizeThatFits(.infinity).width

					// if the max and current view are the same, the views can’t grow
					// update the cache for this view to indicate it cannot grow
					if subviewInfo.length == width {
						cache.subviewInfo[index].updateType(.regular(canGrow: false))
						totalNonRelativeWidth -= width
						totalFixedWidthRegular += width
					}
				}
			}

			// cache the multiplier for the remaining views without relativeStackPortion applied that are able to grow
			cache.nonRelativeMultiplier = (nonSpacingWidth - totalFixedWidthRegular - totalMultipliedWidth) / totalNonRelativeWidth
		}

		// set remaining cache values and return size

		cache.maxAlignmentOffset = maxXOffset

		cache.totalLength = width

		return CGSize(width: width, height: maxHeight)
	}

	public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout RelativeCacheInfo) {
		var bounds = bounds

		// sometimes SwiftUI will call placeSubviews with a size without first
		// calling sizeThatFits with that size, rendering the cache invalid
		// if tthat is the case, call sizeThatFits to update the cache
		if bounds.width != cache.totalLength {
			bounds.size = sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
		}

		var x: CGFloat = bounds.minX
		let nonRelativeMultiplier = cache.nonRelativeMultiplier


		for (index, subview) in subviews.enumerated() {
			let subviewInfo = cache.subviewInfo[index]

			let subviewWidth = switch subviewInfo.type {
				case .spacer:
					cache.spacerLength
				case .regular(let canGrow):
					subviewInfo.length * (canGrow ? nonRelativeMultiplier : 1.0)
				case .relative:
					subviewInfo.length
			}

			// alignments other than .leading will always “push” the subviews forward
			// let's bring them back based on the maximum alignment offset
			let y = bounds.minY - subviewInfo.alignmentOffset + cache.maxAlignmentOffset

			subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: subviewWidth, height: proposal.height))
			x += subviewWidth + spacing
		}
	}
}

#if DEBUG
#Preview {
	RelativeHStack(alignment: .center, spacing: 1.0) {
		Color.green
			.relativeStackPortion(0.3)
			.frame(height: 50)
		Color.yellow
			.frame(height: 250)
		Color.orange
		Text("Red")
			.foregroundStyle(.red)
		Color.purple
			.frame(height: 250)
		Color.blue
			.frame(height: 200)
			.relativeStackPortion(0.15)
	}
	.frame(width: 300, height: 300)
	.border(.black)
	.padding(100)
}
#endif
