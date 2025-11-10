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

#if compiler(>=6.2)
/// Designates a type as having a sendable metatype.
@_marker public protocol _SendableMetatype: SendableMetatype {}
#else
@_marker public protocol _SendableMetatype {}
#endif
