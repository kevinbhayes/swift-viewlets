//
//  AsyncValueStream.swift
//  Common-iOS
//
//  Created by Kevin Hayes on 2024-04-10.
//

import SwiftUI
import Swiftlets

/// To register an action from a SwiftUI view, use the modifier
/// `.onReceive(_ stream: AsyncValueStream, action AsyncValueStream.Action)`
/// The action will be degistered when the view is removed from the hierarchy.
///

private struct AsyncValueStreamViewModifier<T: Sendable>: ViewModifier {
	@State var viewActionId: AsyncValueStream<T>.ID?

	let valueStream: AsyncValueStream<T>
	let action: AsyncValueStream<T>.Action

	func body(content: Content) -> some View {
		content
			.task {
				viewActionId = await valueStream.registerAction { value in
					await action(value)
				}
			}
			.onDisappear {
				if let viewActionId {
					Task {
						await valueStream.deregisterAction(viewActionId)
					}
				}
			}
	}
}

extension View {
	/// Registers an action to be called when a value is sent on the given AsyncValueStream instance
	/// - Parameters:
	///   - stream: the AsyncValueStream that is sending the values
	///   - action: the action to be run when a value is received. This action provides the value as an argument.
	/// - Returns: A view that triggers `action` when the stream yields a value
	///
	/// You do not need to deregister the action. It will automatically do so when the view is removed from the SwiftUI view hierarchy.
	func onReceive<T: Sendable>(_ stream: AsyncValueStream<T>, action: @escaping AsyncValueStream<T>.Action) -> some View {
		modifier(AsyncValueStreamViewModifier<T>(valueStream: stream, action: action))
	}

	/// Registers an action from a SwiftUI view to be called when Void is sent on the given AsyncValueStream instance
	///   - stream: the AsyncValueStream that is sending the values
	///   - action: the action to be run when Void is received. This action provides a Void argument.
	/// - Returns: A view that triggers `action` when the stream yields Void
	///
	/// You do not need to deregister the action. It will automatically do so when the view is removed from the SwiftUI view hierarchy.
	func onReceive(_ stream: AsyncValueStream<Void>, action: @escaping AsyncValueStream<Void>.VoidAction) -> some View {
		modifier(AsyncValueStreamViewModifier<Void>(valueStream: stream, action: action))
	}
}

#if DEBUG
struct AsyncValueStreamView: View {
	@State private var publisher = AsyncValueStream<Int>()

	@State private var currentValue = 0

	var body: some View {
		VStack(spacing: 32) {
			Text("Value: \(currentValue)")
			Button("Publish") {
				publisher.send(Int.random(in: 1 ... 100))
			}
			Button("Cancel Publish") {
				Task {
					await publisher.stop()
				}
			}
		}
		.onReceive(publisher) { @MainActor value in
			currentValue = value
		}
	}
}

#Preview {
	AsyncValueStreamView()
}

#endif
