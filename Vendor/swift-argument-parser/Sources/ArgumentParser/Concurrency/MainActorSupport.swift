//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Argument Parser open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

internal import Foundation
@preconcurrency private import Dispatch

/// A command whose configuration is defined on the `MainActor`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@preconcurrency
public protocol MainActorParsableCommand: ParsableCommand {
  /// Override in conforming commands to describe the configuration on the `MainActor`.
  @MainActor static var mainActorConfiguration: CommandConfiguration { get }
}

/// An async command whose configuration is defined on the `MainActor`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
@preconcurrency
public protocol MainActorAsyncParsableCommand: MainActorParsableCommand, AsyncParsableCommand {
  /// Main-actor entry point for async commands.
  @MainActor mutating func runMainActor() async throws
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension MainActorAsyncParsableCommand {
  @MainActor
  public mutating func run() async throws {
    try await self.runMainActor()
  }
}

@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
extension MainActorParsableCommand {
  @MainActor
  public static var mainActorConfiguration: CommandConfiguration {
    CommandConfiguration()
  }

  /// Bridges the `MainActor`-isolated configuration back to ArgumentParser's global requirement.
  public nonisolated(unsafe) static var configuration: CommandConfiguration {
    if Thread.isMainThread {
      return MainActor.assumeIsolated {
        Self.mainActorConfiguration
      }
    }

    return DispatchQueue.main.sync {
      MainActor.assumeIsolated {
        Self.mainActorConfiguration
      }
    }
  }
}

/// Helper that executes a `CommandConfiguration` builder on the `MainActor`.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
public enum MainActorCommandConfiguration {
  public static func describe(
    _ body: @MainActor @Sendable () -> CommandConfiguration
  ) -> CommandConfiguration {
    resolve(body)
  }

  @usableFromInline
  static func resolve(
    _ body: @MainActor @Sendable () -> CommandConfiguration
  ) -> CommandConfiguration {
    if Thread.isMainThread {
      return MainActor.assumeIsolated(body)
    }

    return DispatchQueue.main.sync {
      MainActor.assumeIsolated(body)
    }
  }
}
