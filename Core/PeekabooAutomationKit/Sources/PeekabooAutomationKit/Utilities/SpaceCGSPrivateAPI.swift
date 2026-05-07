@preconcurrency import CoreFoundation
import CoreGraphics

// MARK: - CGSSpace Private API Declarations

/// Connection identifier for communicating with WindowServer
public typealias CGSConnectionID = UInt32

/// Unique identifier for a Space (virtual desktop)
public typealias CGSSpaceID = UInt64 // size_t in C

/// Managed display identifier
public typealias CGSManagedDisplay = UInt32

/// Window level (z-order)
public typealias CGWindowLevel = Int32

/// Space type enum
public typealias CGSSpaceType = Int

/// Use _CGSDefaultConnection instead of CGSMainConnectionID for better reliability
@_silgen_name("_CGSDefaultConnection")
func _CGSDefaultConnection() -> CGSConnectionID

/// Returns an array of all space IDs matching the given mask
/// The result is a CFArray that may contain space IDs as NSNumbers
@_silgen_name("CGSCopySpaces")
func CGSCopySpaces(_ cid: CGSConnectionID, _ mask: Int) -> CFArray?

/// Given an array of window numbers, returns the IDs of the spaces those windows lie on
/// The windowIDs parameter should be a CFArray of CGWindowID values
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int, _ windowIDs: CFArray) -> CFArray?

/// Gets the type of a space (user, fullscreen, system)
@_silgen_name("CGSSpaceGetType")
func CGSSpaceGetType(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CGSSpaceType

/// Gets the ID of the space currently visible to the user
@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

/// Creates a new space with the given options dictionary
/// Valid keys are: "type": CFNumberRef, "uuid": CFStringRef
@_silgen_name("CGSSpaceCreate")
func CGSSpaceCreate(_ cid: CGSConnectionID, _ null: UnsafeRawPointer, _ options: CFDictionary) -> CGSSpaceID

/// Removes and destroys the space corresponding to the given space ID
@_silgen_name("CGSSpaceDestroy")
func CGSSpaceDestroy(_ cid: CGSConnectionID, _ sid: CGSSpaceID)

/// Get and set the human-readable name of a space
@_silgen_name("CGSSpaceCopyName")
func CGSSpaceCopyName(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CFString

@_silgen_name("CGSSpaceSetName")
func CGSSpaceSetName(_ cid: CGSConnectionID, _ sid: CGSSpaceID, _ name: CFString) -> CGError

/// Returns an array of PIDs of applications that have ownership of a given space
@_silgen_name("CGSSpaceCopyOwners")
func CGSSpaceCopyOwners(_ cid: CGSConnectionID, _ sid: CGSSpaceID) -> CFArray

/// Connection-local data in a given space
@_silgen_name("CGSSpaceCopyValues")
func CGSSpaceCopyValues(_ cid: CGSConnectionID, _ space: CGSSpaceID) -> CFDictionary

@_silgen_name("CGSSpaceSetValues")
func CGSSpaceSetValues(_ cid: CGSConnectionID, _ sid: CGSSpaceID, _ values: CFDictionary) -> CGError

/// Changes the active space for a given display
/// Takes a CFString display identifier
@_silgen_name("CGSManagedDisplaySetCurrentSpace")
func CGSManagedDisplaySetCurrentSpace(_ cid: CGSConnectionID, _ display: CFString, _ space: CGSSpaceID)

/// Given an array of space IDs, each space is shown to the user
@_silgen_name("CGSShowSpaces")
func CGSShowSpaces(_ cid: CGSConnectionID, _ spaces: CFArray)

/// Given an array of space IDs, each space is hidden from the user
@_silgen_name("CGSHideSpaces")
func CGSHideSpaces(_ cid: CGSConnectionID, _ spaces: CFArray)

/// Main display identifier constant
@_silgen_name("kCGSPackagesMainDisplayIdentifier")
let kCGSPackagesMainDisplayIdentifier: CFString

/// Given an array of window numbers and an array of space IDs, adds each window to each space
@_silgen_name("CGSAddWindowsToSpaces")
func CGSAddWindowsToSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

/// Given an array of window numbers and an array of space IDs, removes each window from each space
@_silgen_name("CGSRemoveWindowsFromSpaces")
func CGSRemoveWindowsFromSpaces(_ cid: CGSConnectionID, _ windows: CFArray, _ spaces: CFArray)

/// Returns information about managed display spaces
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray

/// Get the level (z-order) of a window
@_silgen_name("CGSGetWindowLevel")
func CGSGetWindowLevel(
    _ cid: CGSConnectionID,
    _ windowID: CGWindowID,
    _ outLevel: UnsafeMutablePointer<CGWindowLevel>) -> CGError

// Space type constants (from CGSSpaceType enum)
let kCGSSpaceUser = 0 // User-created desktop spaces
let kCGSSpaceFullscreen = 1 // Fullscreen spaces
let kCGSSpaceSystem = 2 // System spaces e.g. Dashboard
let kCGSSpaceTiled = 5 // Tiled spaces (newer macOS)

// Space mask constants (from CGSSpaceMask enum)
let kCGSSpaceIncludesCurrent = 1 << 0
let kCGSSpaceIncludesOthers = 1 << 1
let kCGSSpaceIncludesUser = 1 << 2
let kCGSSpaceVisible = 1 << 16

let kCGSCurrentSpaceMask = kCGSSpaceIncludesUser | kCGSSpaceIncludesCurrent
let kCGSOtherSpacesMask = kCGSSpaceIncludesOthers | kCGSSpaceIncludesCurrent
let kCGSAllSpacesMask = kCGSSpaceIncludesUser | kCGSSpaceIncludesOthers | kCGSSpaceIncludesCurrent
let kCGSAllVisibleSpacesMask = kCGSSpaceVisible | kCGSAllSpacesMask
