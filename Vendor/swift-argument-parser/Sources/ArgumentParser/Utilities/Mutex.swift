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

#if canImport(os)
internal import os
#if canImport(C.os.lock)
internal import C.os.lock
#endif
#elseif canImport(Bionic)
@preconcurrency import Bionic
#elseif canImport(Glibc)
@preconcurrency import Glibc
#elseif canImport(Musl)
@preconcurrency import Musl
#elseif canImport(WinSDK)
import WinSDK
#endif

struct Mutex<State> {
  // Internal implementation for a cheap lock to aid sharing code across platforms
  private struct _Lock {
    #if canImport(os)
    typealias Primitive = os_unfair_lock
    #elseif os(FreeBSD) || os(OpenBSD)
    typealias Primitive = pthread_mutex_t?
    #elseif canImport(Bionic) || canImport(Glibc) || canImport(Musl)
    typealias Primitive = pthread_mutex_t
    #elseif canImport(WinSDK)
    typealias Primitive = SRWLOCK
    #elseif os(WASI)
    // WASI is single-threaded, so we don't need a lock.
    typealias Primitive = Void
    #endif

    typealias PlatformLock = UnsafeMutablePointer<Primitive>
    var _platformLock: PlatformLock

    fileprivate static func initialize(_ platformLock: PlatformLock) {
      #if canImport(os)
      platformLock.initialize(to: os_unfair_lock())
      #elseif canImport(Bionic) || canImport(Glibc) || canImport(Musl)
      pthread_mutex_init(platformLock, nil)
      #elseif canImport(WinSDK)
      InitializeSRWLock(platformLock)
      #elseif os(WASI)
      // no-op
      #else
      #error("Lock._Lock.initialize is unimplemented on this platform")
      #endif
    }

    fileprivate static func deinitialize(_ platformLock: PlatformLock) {
      #if canImport(Bionic) || canImport(Glibc) || canImport(Musl)
      pthread_mutex_destroy(platformLock)
      #endif
      platformLock.deinitialize(count: 1)
    }

    static fileprivate func lock(_ platformLock: PlatformLock) {
      #if canImport(os)
      os_unfair_lock_lock(platformLock)
      #elseif canImport(Bionic) || canImport(Glibc) || canImport(Musl)
      pthread_mutex_lock(platformLock)
      #elseif canImport(WinSDK)
      AcquireSRWLockExclusive(platformLock)
      #elseif os(WASI)
      // no-op
      #else
      #error("Lock._Lock.lock is unimplemented on this platform")
      #endif
    }

    static fileprivate func unlock(_ platformLock: PlatformLock) {
      #if canImport(os)
      os_unfair_lock_unlock(platformLock)
      #elseif canImport(Bionic) || canImport(Glibc) || canImport(Musl)
      pthread_mutex_unlock(platformLock)
      #elseif canImport(WinSDK)
      ReleaseSRWLockExclusive(platformLock)
      #elseif os(WASI)
      // no-op
      #else
      #error("Lock._Lock.unlock is unimplemented on this platform")
      #endif
    }
  }

  private class _Buffer: ManagedBuffer<State, _Lock.Primitive> {
    deinit {
      withUnsafeMutablePointerToElements {
        _Lock.deinitialize($0)
      }
    }
  }

  private let _buffer: ManagedBuffer<State, _Lock.Primitive>

  init(_ initialState: State) {
    _buffer = _Buffer.create(
      minimumCapacity: 1,
      makingHeaderWith: { buf in
        buf.withUnsafeMutablePointerToElements {
          _Lock.initialize($0)
        }
        return initialState
      })
  }

  func withLock<T>(_ body: @Sendable (inout State) throws -> T) rethrows -> T {
    try withLockUnchecked(body)
  }

  func withLockUnchecked<T>(_ body: (inout State) throws -> T) rethrows -> T {
    try _buffer.withUnsafeMutablePointers { state, lock in
      _Lock.lock(lock)
      defer { _Lock.unlock(lock) }
      return try body(&state.pointee)
    }
  }

  // Ensures the managed state outlives the locked scope.
  func withLockExtendingLifetimeOfState<T>(
    _ body: @Sendable (inout State) throws -> T
  ) rethrows -> T {
    try _buffer.withUnsafeMutablePointers { state, lock in
      _Lock.lock(lock)
      return try withExtendedLifetime(state.pointee) {
        defer { _Lock.unlock(lock) }
        return try body(&state.pointee)
      }
    }
  }
}

extension Mutex: @unchecked Sendable where State: Sendable {}
