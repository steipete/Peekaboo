---
summary: 'Review ifndef CGS_ACCESSIBILITY_INTERNAL_H guidance'
read_when:
  - 'planning work related to ifndef cgs_accessibility_internal_h'
  - 'debugging or extending features described here'
---

Directory Structure:

└── ./
    ├── CGSAccessibility.h
    ├── CGSCIFilter.h
    ├── CGSConnection.h
    ├── CGSCursor.h
    ├── CGSDebug.h
    ├── CGSDevice.h
    ├── CGSDisplays.h
    ├── CGSEvent.h
    ├── CGSHotKeys.h
    ├── CGSInternal.h
    ├── CGSMisc.h
    ├── CGSRegion.h
    ├── CGSSession.h
    ├── CGSSpace.h
    ├── CGSSurface.h
    ├── CGSTile.h
    ├── CGSTransitions.h
    ├── CGSWindow.h
    └── CGSWorkspace.h



---
File: /CGSAccessibility.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_ACCESSIBILITY_INTERNAL_H
#define CGS_ACCESSIBILITY_INTERNAL_H

#include "CGSConnection.h"


#pragma mark - Display Zoom


/// Gets whether the display is zoomed.
CG_EXTERN CGError CGSIsZoomed(CGSConnectionID cid, bool *outIsZoomed);


#pragma mark - Invert Colors


/// Gets the preference value for inverted colors on the current display.
CG_EXTERN bool CGDisplayUsesInvertedPolarity(void);

/// Sets the preference value for the state of the inverted colors on the current display.  This
/// preference value is monitored by the system, and updating it causes a fairly immediate change
/// in the screen's colors.
///
/// Internally, this sets and synchronizes `DisplayUseInvertedPolarity` in the
/// "com.apple.CoreGraphics" preferences bundle.
CG_EXTERN void CGDisplaySetInvertedPolarity(bool invertedPolarity);


#pragma mark - Use Grayscale


/// Gets whether the screen forces all drawing as grayscale.
CG_EXTERN bool CGDisplayUsesForceToGray(void);

/// Sets whether the screen forces all drawing as grayscale.
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);


#pragma mark - Increase Contrast


/// Sets the display's contrast. There doesn't seem to be a get version of this function.
CG_EXTERN CGError CGSSetDisplayContrast(CGFloat contrast);

#endif /* CGS_ACCESSIBILITY_INTERNAL_H */



---
File: /CGSCIFilter.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_CIFILTER_INTERNAL_H
#define CGS_CIFILTER_INTERNAL_H

#include "CGSConnection.h"

typedef enum {
	kCGWindowFilterUnderlay		= 1,
	kCGWindowFilterDock			= 0x3001,
} CGSCIFilterID;

/// Creates a new filter from a filter name.
///
/// Any valid CIFilter names are valid names for this function.
CG_EXTERN CGError CGSNewCIFilterByName(CGSConnectionID cid, CFStringRef filterName, CGSCIFilterID *outFilter);

/// Inserts the given filter into the window.
///
/// The values for the `flags` field is currently unknown.
CG_EXTERN CGError CGSAddWindowFilter(CGSConnectionID cid, CGWindowID wid, CGSCIFilterID filter, int flags);

/// Removes the given filter from the window.
CG_EXTERN CGError CGSRemoveWindowFilter(CGSConnectionID cid, CGWindowID wid, CGSCIFilterID filter);

/// Invokes `-[CIFilter setValue:forKey:]` on each entry in the dictionary for the window's filter.
///
/// The Window Server only checks for the existence of
///
///    inputPhase
///    inputPhase0
///    inputPhase1
CG_EXTERN CGError CGSSetCIFilterValuesFromDictionary(CGSConnectionID cid, CGSCIFilterID filter, CFDictionaryRef filterValues);

/// Releases a window's CIFilter.
CG_EXTERN CGError CGSReleaseCIFilter(CGSConnectionID cid, CGSCIFilterID filter);

#endif /* CGS_CIFILTER_INTERNAL_H */



---
File: /CGSConnection.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_CONNECTION_INTERNAL_H
#define CGS_CONNECTION_INTERNAL_H

/// The type of connections to the Window Server.
///
/// Every application is given a singular connection ID through which it can receieve and manipulate
/// values, state, notifications, events, etc. in the Window Server.  It
typedef int CGSConnectionID;

typedef void *CGSNotificationData;
typedef void *CGSNotificationArg;
typedef int CGSTransitionID;


#pragma mark - Connection Lifecycle


/// Gets the default connection for this process.
CG_EXTERN CGSConnectionID CGSMainConnectionID(void);

/// Creates a new connection to the Window Server.
CG_EXTERN CGError CGSNewConnection(int unused, CGSConnectionID *outConnection);

/// Releases a CGSConnection and all CGSWindows owned by it.
CG_EXTERN CGError CGSReleaseConnection(CGSConnectionID cid);

/// Gets the default connection for the current thread.
CG_EXTERN CGSConnectionID CGSDefaultConnectionForThread(void);

/// Gets the pid of the process that owns this connection to the Window Server.
CG_EXTERN CGError CGSConnectionGetPID(CGSConnectionID cid, pid_t *outPID);

/// Gets the connection for the given process serial number.
CG_EXTERN CGError CGSGetConnectionIDForPSN(CGSConnectionID cid, const ProcessSerialNumber *psn, CGSConnectionID *outOwnerCID);

/// Returns whether the menu bar exists for the given connection ID.
///
/// For the majority of applications, this function should return true.  But at system updates,
/// initialization, and shutdown, the menu bar will be either initially gone then created or
/// hidden and then destroyed.
CG_EXTERN bool CGSMenuBarExists(CGSConnectionID cid);

/// Closes ALL connections to the Window Server by the current application.
///
/// The application is effectively turned into a Console-based application after the invocation of
/// this method.
CG_EXTERN CGError CGSShutdownServerConnections(void);


#pragma mark - Connection Properties


/// Retrieves the value associated with the given key for the given connection.
///
/// This method is structured so processes can send values through the Window Server to other
/// processes - assuming they know each others connection IDs.  The recommended use case for this
/// function appears to be keeping state around for application-level sub-connections.
CG_EXTERN CGError CGSCopyConnectionProperty(CGSConnectionID cid, CGSConnectionID targetCID, CFStringRef key, CFTypeRef *outValue);

/// Associates a value for the given key on the given connection.
CG_EXTERN CGError CGSSetConnectionProperty(CGSConnectionID cid, CGSConnectionID targetCID, CFStringRef key, CFTypeRef value);


#pragma mark - Connection Updates


/// Disables updates on a connection
///
/// Calls to disable updates nest much like `-beginUpdates`/`-endUpdates`.  the Window Server will
/// forcibly reenable updates after 1 second if you fail to invoke `CGSReenableUpdate`.
CG_EXTERN CGError CGSDisableUpdate(CGSConnectionID cid);

/// Re-enables updates on a connection.
///
/// Calls to enable updates nest much like `-beginUpdates`/`-endUpdates`.
CG_EXTERN CGError CGSReenableUpdate(CGSConnectionID cid);


#pragma mark - Connection Notifications


typedef void (*CGSNewConnectionNotificationProc)(CGSConnectionID cid);

/// Registers a function that gets invoked when the application's connection ID is created by the
/// Window Server.
CG_EXTERN CGError CGSRegisterForNewConnectionNotification(CGSNewConnectionNotificationProc proc);

/// Removes a function that was registered to receive notifications for the creation of the
/// application's connection to the Window Server.
CG_EXTERN CGError CGSRemoveNewConnectionNotification(CGSNewConnectionNotificationProc proc);

typedef void (*CGSConnectionDeathNotificationProc)(CGSConnectionID cid);

/// Registers a function that gets invoked when the application's connection ID is destroyed -
/// ideally by the Window Server.
///
/// Connection death is supposed to be a fatal event that is only triggered when the application
/// terminates or when you have explicitly destroyed a sub-connection to the Window Server.
CG_EXTERN CGError CGSRegisterForConnectionDeathNotification(CGSConnectionDeathNotificationProc proc);

/// Removes a function that was registered to receive notifications for the destruction of the
/// application's connection to the Window Server.
CG_EXTERN CGError CGSRemoveConnectionDeathNotification(CGSConnectionDeathNotificationProc proc);


#pragma mark - Miscellaneous Security Holes

/// Sets a "Universal Owner" for the connection ID.  Currently, that owner is Dock.app, which needs
/// control over the window to provide system features like hiding and showing windows, moving them
/// around, etc.
///
/// Because the Universal Owner owns every window under this connection, it can manipulate them
/// all as it sees fit.  If you can beat the dock, you have total control over the process'
/// connection.
CG_EXTERN CGError CGSSetUniversalOwner(CGSConnectionID cid);

/// Assuming you have the connection ID of the current universal owner, or are said universal owner,
/// allows you to specify another connection that has total control over the application's windows.
CG_EXTERN CGError CGSSetOtherUniversalConnection(CGSConnectionID cid, CGSConnectionID otherConnection);

/// Sets the given connection ID as the login window connection ID.  Windows for the application are
/// then brought to the fore when the computer logs off or goes to sleep.
///
/// Why this is still here, I have no idea.  Window Server only accepts one process calling this
/// ever.  If you attempt to invoke this after loginwindow does you will be yelled at and nothing
/// will happen.  If you can manage to beat loginwindow, however, you know what they say:
///
///    When you teach a man to phish...
CG_EXTERN CGError CGSSetLoginwindowConnection(CGSConnectionID cid) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;

//! The data sent with kCGSNotificationAppUnresponsive and kCGSNotificationAppResponsive.
typedef struct {
#if __BIG_ENDIAN__
	uint16_t majorVersion;
	uint16_t minorVersion;
#else
	uint16_t minorVersion;
	uint16_t majorVersion;
#endif

	//! The length of the entire notification.
	uint32_t length;

	CGSConnectionID cid;
	pid_t pid;
	ProcessSerialNumber psn;
} CGSProcessNotificationData;

//! The data sent with kCGSNotificationDebugOptionsChanged.
typedef struct {
	int newOptions;
	int unknown[2]; // these two seem to be zero
} CGSDebugNotificationData;

//! The data sent with kCGSNotificationTransitionEnded
typedef struct {
	CGSTransitionID transition;
} CGSTransitionNotificationData;

#endif /* CGS_CONNECTION_INTERNAL_H */



---
File: /CGSCursor.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_CURSOR_INTERNAL_H
#define CGS_CURSOR_INTERNAL_H

#include "CGSConnection.h"

typedef enum : NSInteger {
	CGSCursorArrow			= 0,
	CGSCursorIBeam			= 1,
	CGSCursorIBeamXOR		= 2,
	CGSCursorAlias			= 3,
	CGSCursorCopy			= 4,
	CGSCursorMove			= 5,
	CGSCursorArrowContext	= 6,
	CGSCursorWait			= 7,
	CGSCursorEmpty			= 8,
} CGSCursorID;


/// Registers a cursor with the given properties.
///
/// - Parameter cid:			The connection ID to register with.
/// - Parameter cursorName:		The system-wide name the cursor will be registered under.
/// - Parameter setGlobally:	Whether the cursor registration can appear system-wide.
/// - Parameter instantly:		Whether the registration of cursor images should occur immediately.  Passing false
///                             may speed up the call.
/// - Parameter frameCount:     The number of images in the cursor image array.
/// - Parameter imageArray:     An array of CGImageRefs that are used to display the cursor.  Multiple images in
///                             conjunction with a non-zero `frameDuration` cause animation.
/// - Parameter cursorSize:     The size of the cursor's images.  Recommended size is 16x16 points
/// - Parameter hotspot:		The location touch events will emanate from.
/// - Parameter seed:			The seed for the cursor's registration.
/// - Parameter bounds:			The total size of the cursor.
/// - Parameter frameDuration:	How long each image will be displayed for.
/// - Parameter repeatCount:	Number of times the cursor should repeat cycling its image frames.
CG_EXTERN CGError CGSRegisterCursorWithImages(CGSConnectionID cid,
											  const char *cursorName,
											  bool setGlobally, bool instantly,
											  NSUInteger frameCount, CFArrayRef imageArray,
											  CGSize cursorSize, CGPoint hotspot,
											  int *seed,
											  CGRect bounds, CGFloat frameDuration,
											  NSInteger repeatCount);


#pragma mark - Cursor Registration


/// Copies the size of data associated with the cursor registered under the given name.
CG_EXTERN CGError CGSGetRegisteredCursorDataSize(CGSConnectionID cid, const char *cursorName, size_t *outDataSize);

/// Re-assigns the given cursor name to the cursor represented by the given seed value.
CG_EXTERN CGError CGSSetRegisteredCursor(CGSConnectionID cid, const char *cursorName, int *cursorSeed);

/// Copies the properties out of the cursor registered under the given name.
CG_EXTERN CGError CGSCopyRegisteredCursorImages(CGSConnectionID cid, const char *cursorName, CGSize *imageSize, CGPoint *hotSpot, NSUInteger *frameCount, CGFloat *frameDuration, CFArrayRef *imageArray);

/// Re-assigns one of the system-defined cursors to the cursor represented by the given seed value.
CG_EXTERN void CGSSetSystemDefinedCursorWithSeed(CGSConnectionID connection, CGSCursorID systemCursor, int *cursorSeed);


#pragma mark - Cursor Display


/// Shows the cursor.
CG_EXTERN CGError CGSShowCursor(CGSConnectionID cid);

/// Hides the cursor.
CG_EXTERN CGError CGSHideCursor(CGSConnectionID cid);

/// Hides the cursor until the cursor is moved.
CG_EXTERN CGError CGSObscureCursor(CGSConnectionID cid);

/// Acts as if a mouse moved event occured and that reveals the cursor if it was hidden.
CG_EXTERN CGError CGSRevealCursor(CGSConnectionID cid);

/// Shows or hides the spinning beachball of death.
///
/// If you call this, I hate you.
CG_EXTERN CGError CGSForceWaitCursorActive(CGSConnectionID cid, bool showWaitCursor);

/// Unconditionally sets the location of the cursor on the screen to the given coordinates.
CG_EXTERN CGError CGSWarpCursorPosition(CGSConnectionID cid, CGFloat x, CGFloat y);


#pragma mark - Cursor Properties


/// Gets the current cursor's seed value.
///
/// Every time the cursor is updated, the seed changes.
CG_EXTERN int CGSCurrentCursorSeed(void);

/// Gets the current location of the cursor relative to the screen's coordinates.
CG_EXTERN CGError CGSGetCurrentCursorLocation(CGSConnectionID cid, CGPoint *outPos);

/// Gets the name (ideally in reverse DNS form) of a system cursor.
CG_EXTERN char *CGSCursorNameForSystemCursor(CGSCursorID cursor);

/// Gets the scale of the current currsor.
CG_EXTERN CGError CGSGetCursorScale(CGSConnectionID cid, CGFloat *outScale);

/// Sets the scale of the current cursor.
///
/// The largest the Universal Access prefpane allows you to go is 4.0.
CG_EXTERN CGError CGSSetCursorScale(CGSConnectionID cid, CGFloat scale);


#pragma mark - Cursor Data


/// Gets the size of the data for the connection's cursor.
CG_EXTERN CGError CGSGetCursorDataSize(CGSConnectionID cid, size_t *outDataSize);

/// Gets the data for the connection's cursor.
CG_EXTERN CGError CGSGetCursorData(CGSConnectionID cid, void *outData);

/// Gets the size of the data for the current cursor.
CG_EXTERN CGError CGSGetGlobalCursorDataSize(CGSConnectionID cid, size_t *outDataSize);

/// Gets the data for the current cursor.
CG_EXTERN CGError CGSGetGlobalCursorData(CGSConnectionID cid, void *outData, int *outDataSize, int *outRowBytes, CGRect *outRect, CGPoint *outHotSpot, int *outDepth, int *outComponents, int *outBitsPerComponent);

/// Gets the size of data for a system-defined cursor.
CG_EXTERN CGError CGSGetSystemDefinedCursorDataSize(CGSConnectionID cid, CGSCursorID cursor, size_t *outDataSize);

/// Gets the data for a system-defined cursor.
CG_EXTERN CGError CGSGetSystemDefinedCursorData(CGSConnectionID cid, CGSCursorID cursor, void *outData, int *outRowBytes, CGRect *outRect, CGPoint *outHotSpot, int *outDepth, int *outComponents, int *outBitsPerComponent);

#endif /* CGS_CURSOR_INTERNAL_H */



---
File: /CGSDebug.h
---

/*
 * Routines for debugging the Window Server and application drawing.
 *
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_DEBUG_INTERNAL_H
#define CGS_DEBUG_INTERNAL_H

#include "CGSConnection.h"

/// The set of options that the Window Server
typedef enum {
	/// Clears all flags.
	kCGSDebugOptionNone							= 0,

	/// All screen updates are flashed in yellow. Regions under a DisableUpdate are flashed in orange. Regions that are hardware accellerated are painted green.
	kCGSDebugOptionFlashScreenUpdates			= 0x4,

	/// Colors windows green if they are accellerated, otherwise red. Doesn't cause things to refresh properly - leaves excess rects cluttering the screen.
	kCGSDebugOptionColorByAccelleration			= 0x20,

	/// Disables shadows on all windows.
	kCGSDebugOptionNoShadows					= 0x4000,

	/// Setting this disables the pause after a flash when using FlashScreenUpdates or FlashIdenticalUpdates.
	kCGSDebugOptionNoDelayAfterFlash			= 0x20000,

	/// Flushes the contents to the screen after every drawing operation.
	kCGSDebugOptionAutoflushDrawing				= 0x40000,

	/// Highlights mouse tracking areas. Doesn't cause things to refresh correctly - leaves excess rectangles cluttering the screen.
	kCGSDebugOptionShowMouseTrackingAreas		= 0x100000,

	/// Flashes identical updates in red.
	kCGSDebugOptionFlashIdenticalUpdates		= 0x4000000,

	/// Dumps a list of windows to /tmp/WindowServer.winfo.out. This is what Quartz Debug uses to get the window list.
	kCGSDebugOptionDumpWindowListToFile			= 0x80000001,

	/// Dumps a list of connections to /tmp/WindowServer.cinfo.out.
	kCGSDebugOptionDumpConnectionListToFile		= 0x80000002,

	/// Dumps a very verbose debug log of the WindowServer to /tmp/CGLog_WinServer_<PID>.
	kCGSDebugOptionVerboseLogging				= 0x80000006,

	/// Dumps a very verbose debug log of all processes to /tmp/CGLog_<NAME>_<PID>.
	kCGSDebugOptionVerboseLoggingAllApps		= 0x80000007,

	/// Dumps a list of hotkeys to /tmp/WindowServer.keyinfo.out.
	kCGSDebugOptionDumpHotKeyListToFile			= 0x8000000E,

	/// Dumps information about OpenGL extensions, etc to /tmp/WindowServer.glinfo.out.
	kCGSDebugOptionDumpOpenGLInfoToFile			= 0x80000013,

	/// Dumps a list of shadows to /tmp/WindowServer.shinfo.out.
	kCGSDebugOptionDumpShadowListToFile			= 0x80000014,

	/// Leopard: Dumps information about caches to `/tmp/WindowServer.scinfo.out`.
	kCGSDebugOptionDumpCacheInformationToFile	= 0x80000015,

	/// Leopard: Purges some sort of cache - most likely the same caches dummped with `kCGSDebugOptionDumpCacheInformationToFile`.
	kCGSDebugOptionPurgeCaches					= 0x80000016,

	/// Leopard: Dumps a list of windows to `/tmp/WindowServer.winfo.plist`. This is what Quartz Debug on 10.5 uses to get the window list.
	kCGSDebugOptionDumpWindowListToPlist		= 0x80000017,

	/// Leopard: DOCUMENTATION PENDING
	kCGSDebugOptionEnableSurfacePurging			= 0x8000001B,

	// Leopard: 0x8000001C - invalid

	/// Leopard: DOCUMENTATION PENDING
	kCGSDebugOptionDisableSurfacePurging		= 0x8000001D,

	/// Leopard: Dumps information about an application's resource usage to `/tmp/CGResources_<NAME>_<PID>`.
	kCGSDebugOptionDumpResourceUsageToFiles		= 0x80000020,

	// Leopard: 0x80000022 - something about QuartzGL?

	// Leopard: Returns the magic mirror to its normal mode. The magic mirror is what the Dock uses to draw the screen reflection. For more information, see `CGSSetMagicMirror`.
	kCGSDebugOptionSetMagicMirrorModeNormal		= 0x80000023,

	/// Leopard: Disables the magic mirror. It still appears but draws black instead of a reflection.
	kCGSDebugOptionSetMagicMirrorModeDisabled	= 0x80000024,
} CGSDebugOption;


/// Gets and sets the debug options.
///
/// These options are global and are not reset when your application dies!
CG_EXTERN CGError CGSGetDebugOptions(int *outCurrentOptions);
CG_EXTERN CGError CGSSetDebugOptions(int options);

/// Queries the server about its performance. This is how Quartz Debug gets the FPS meter, but not
/// the CPU meter (for that it uses host_processor_info). Quartz Debug subtracts 25 so that it is at
/// zero with the minimum FPS.
CG_EXTERN CGError CGSGetPerformanceData(CGSConnectionID cid, CGFloat *outFPS, CGFloat *unk, CGFloat *unk2, CGFloat *unk3);

#endif /* CGS_DEBUG_INTERNAL_H */



---
File: /CGSDevice.h
---

//
//  CGSDevice.h
//  CGSInternal
//
//  Created by Robert Widmann on 9/14/13.
//  Copyright (c) 2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//


#ifndef CGS_DEVICE_INTERNAL_H
#define CGS_DEVICE_INTERNAL_H

#include "CGSConnection.h"

/// Actuates the Taptic Engine underneath the user's fingers.
///
/// Valid patterns are in the range 0x1-0x6 and 0xf-0x10 inclusive.
///
/// Currently, deviceID and strength must be 0 as non-zero configurations are not
/// yet supported
CG_EXTERN CGError CGSActuateDeviceWithPattern(CGSConnectionID cid, int deviceID, int pattern, int strength) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

/// Overrides the current pressure configuration with the given configuration.
CG_EXTERN CGError CGSSetPressureConfigurationOverride(CGSConnectionID cid, int deviceID, void *config) AVAILABLE_MAC_OS_X_VERSION_10_10_3_AND_LATER;

#endif /* CGSDevice_h */



---
File: /CGSDisplays.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 * Ryan Govostes ryan@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_DISPLAYS_INTERNAL_H
#define CGS_DISPLAYS_INTERNAL_H

#include "CGSRegion.h"

typedef enum {
	CGSDisplayQueryMirrorStatus = 9,
} CGSDisplayQuery;

typedef struct {
	uint32_t mode;
	uint32_t flags;
	uint32_t width;
	uint32_t height;
	uint32_t depth;
	uint32_t dc2[42];
	uint16_t dc3;
	uint16_t freq;
	uint8_t dc4[16];
	CGFloat scale;
} CGSDisplayModeDescription;

typedef int CGSDisplayMode;


/// Gets the main display.
CG_EXTERN CGDirectDisplayID CGSMainDisplayID(void);


#pragma mark - Display Properties


/// Gets the number of displays known to the system.
CG_EXTERN uint32_t CGSGetNumberOfDisplays(void);

/// Gets the depth of a display.
CG_EXTERN CGError CGSGetDisplayDepth(CGDirectDisplayID display, int *outDepth);

/// Gets the displays at a point. Note that multiple displays can have the same point - think mirroring.
CG_EXTERN CGError CGSGetDisplaysWithPoint(const CGPoint *point, int maxDisplayCount, CGDirectDisplayID *outDisplays, int *outDisplayCount);

/// Gets the displays which contain a rect. Note that multiple displays can have the same bounds - think mirroring.
CG_EXTERN CGError CGSGetDisplaysWithRect(const CGRect *point, int maxDisplayCount, CGDirectDisplayID *outDisplays, int *outDisplayCount);

/// Gets the bounds for the display. Note that multiple displays can have the same bounds - think mirroring.
CG_EXTERN CGError CGSGetDisplayRegion(CGDirectDisplayID display, CGSRegionRef *outRegion);
CG_EXTERN CGError CGSGetDisplayBounds(CGDirectDisplayID display, CGRect *outRect);

/// Gets the number of bytes per row.
CG_EXTERN CGError CGSGetDisplayRowBytes(CGDirectDisplayID display, int *outRowBytes);

/// Returns an array of dictionaries describing the spaces each screen contains.
CG_EXTERN CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);

/// Gets the current display mode for the display.
CG_EXTERN CGError CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);

/// Gets the number of possible display modes for the display.
CG_EXTERN CGError CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);

/// Gets a description of the mode of the display.
CG_EXTERN CGError CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayModeDescription *desc, int length);

/// Sets a display's configuration mode.
CG_EXTERN CGError CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);

/// Gets a list of on line displays */
CG_EXTERN CGDisplayErr CGSGetOnlineDisplayList(CGDisplayCount maxDisplays, CGDirectDisplayID *displays, CGDisplayCount *outDisplayCount);

/// Gets a list of active displays */
CG_EXTERN CGDisplayErr CGSGetActiveDisplayList(CGDisplayCount maxDisplays, CGDirectDisplayID *displays, CGDisplayCount *outDisplayCount);


#pragma mark - Display Configuration


/// Begins a new display configuration transacation.
CG_EXTERN CGDisplayErr CGSBeginDisplayConfiguration(CGDisplayConfigRef *config);

/// Sets the origin of a display relative to the main display. The main display is at (0, 0) and contains the menubar.
CG_EXTERN CGDisplayErr CGSConfigureDisplayOrigin(CGDisplayConfigRef config, CGDirectDisplayID display, int32_t x, int32_t y);

/// Applies the configuration changes made in this transaction.
CG_EXTERN CGDisplayErr CGSCompleteDisplayConfiguration(CGDisplayConfigRef config);

/// Drops the configuration changes made in this transaction.
CG_EXTERN CGDisplayErr CGSCancelDisplayConfiguration(CGDisplayConfigRef config);


#pragma mark - Querying for Display Status


/// Queries the Window Server about the status of the query.
CG_EXTERN CGError CGSDisplayStatusQuery(CGDirectDisplayID display, CGSDisplayQuery query);

#endif /* CGS_DISPLAYS_INTERNAL_H */



---
File: /CGSEvent.h
---

//
//  CGSEvent.h
//  CGSInternal
//
//  Created by Robert Widmann on 9/14/13.
//  Copyright (c) 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_EVENT_INTERNAL_H
#define CGS_EVENT_INTERNAL_H

#include "CGSWindow.h"

typedef unsigned long CGSByteCount;
typedef unsigned short CGSEventRecordVersion;
typedef unsigned long long CGSEventRecordTime;  /* nanosecond timer */
typedef unsigned long CGSEventFlag;
typedef unsigned long  CGSError;

typedef enum : unsigned int {
	kCGSDisplayWillReconfigure = 100,
	kCGSDisplayDidReconfigure = 101,
	kCGSDisplayWillSleep = 102,
	kCGSDisplayDidWake = 103,
	kCGSDisplayIsCaptured = 106,
	kCGSDisplayIsReleased = 107,
	kCGSDisplayAllDisplaysReleased = 108,
	kCGSDisplayHardwareChanged = 111,
	kCGSDisplayDidReconfigure2 = 115,
	kCGSDisplayFullScreenAppRunning = 116,
	kCGSDisplayFullScreenAppDone = 117,
	kCGSDisplayReconfigureHappened = 118,
	kCGSDisplayColorProfileChanged = 119,
	kCGSDisplayZoomStateChanged = 120,
	kCGSDisplayAcceleratorChanged = 121,
	kCGSDebugOptionsChangedNotification = 200,
	kCGSDebugPrintResourcesNotification = 203,
	kCGSDebugPrintResourcesMemoryNotification = 205,
	kCGSDebugPrintResourcesContextNotification = 206,
	kCGSDebugPrintResourcesImageNotification = 208,
	kCGSServerConnDirtyScreenNotification = 300,
	kCGSServerLoginNotification = 301,
	kCGSServerShutdownNotification = 302,
	kCGSServerUserPreferencesLoadedNotification = 303,
	kCGSServerUpdateDisplayNotification = 304,
	kCGSServerCAContextDidCommitNotification = 305,
	kCGSServerUpdateDisplayCompletedNotification = 306,

	kCPXForegroundProcessSwitched = 400,
	kCPXSpecialKeyPressed = 401,
	kCPXForegroundProcessSwitchRequestedButRedundant = 402,

	kCGSSpecialKeyEventNotification = 700,

	kCGSEventNotificationNullEvent = 710,
	kCGSEventNotificationLeftMouseDown = 711,
	kCGSEventNotificationLeftMouseUp = 712,
	kCGSEventNotificationRightMouseDown = 713,
	kCGSEventNotificationRightMouseUp = 714,
	kCGSEventNotificationMouseMoved = 715,
	kCGSEventNotificationLeftMouseDragged = 716,
	kCGSEventNotificationRightMouseDragged = 717,
	kCGSEventNotificationMouseEntered = 718,
	kCGSEventNotificationMouseExited = 719,

	kCGSEventNotificationKeyDown = 720,
	kCGSEventNotificationKeyUp = 721,
	kCGSEventNotificationFlagsChanged = 722,
	kCGSEventNotificationKitDefined = 723,
	kCGSEventNotificationSystemDefined = 724,
	kCGSEventNotificationApplicationDefined = 725,
	kCGSEventNotificationTimer = 726,
	kCGSEventNotificationCursorUpdate = 727,
	kCGSEventNotificationSuspend = 729,
	kCGSEventNotificationResume = 730,
	kCGSEventNotificationNotification = 731,
	kCGSEventNotificationScrollWheel = 732,
	kCGSEventNotificationTabletPointer = 733,
	kCGSEventNotificationTabletProximity = 734,
	kCGSEventNotificationOtherMouseDown = 735,
	kCGSEventNotificationOtherMouseUp = 736,
	kCGSEventNotificationOtherMouseDragged = 737,
	kCGSEventNotificationZoom = 738,
	kCGSEventNotificationAppIsUnresponsive = 750,
	kCGSEventNotificationAppIsNoLongerUnresponsive = 751,

	kCGSEventSecureTextInputIsActive = 752,
	kCGSEventSecureTextInputIsOff = 753,

	kCGSEventNotificationSymbolicHotKeyChanged = 760,
	kCGSEventNotificationSymbolicHotKeyDisabled = 761,
	kCGSEventNotificationSymbolicHotKeyEnabled = 762,
	kCGSEventNotificationHotKeysGloballyDisabled = 763,
	kCGSEventNotificationHotKeysGloballyEnabled = 764,
	kCGSEventNotificationHotKeysExceptUniversalAccessGloballyDisabled = 765,
	kCGSEventNotificationHotKeysExceptUniversalAccessGloballyEnabled = 766,

	kCGSWindowIsObscured = 800,
	kCGSWindowIsUnobscured = 801,
	kCGSWindowIsOrderedIn = 802,
	kCGSWindowIsOrderedOut = 803,
	kCGSWindowIsTerminated = 804,
	kCGSWindowIsChangingScreens = 805,
	kCGSWindowDidMove = 806,
	kCGSWindowDidResize = 807,
	kCGSWindowDidChangeOrder = 808,
	kCGSWindowGeometryDidChange = 809,
	kCGSWindowMonitorDataPending = 810,
	kCGSWindowDidCreate = 811,
	kCGSWindowRightsGrantOffered = 812,
	kCGSWindowRightsGrantCompleted = 813,
	kCGSWindowRecordForTermination = 814,
	kCGSWindowIsVisible = 815,
	kCGSWindowIsInvisible = 816,

	kCGSLikelyUnbalancedDisableUpdateNotification = 902,

	kCGSConnectionWindowsBecameVisible = 904,
	kCGSConnectionWindowsBecameOccluded = 905,
	kCGSConnectionWindowModificationsStarted = 906,
	kCGSConnectionWindowModificationsStopped = 907,

	kCGSWindowBecameVisible = 912,
	kCGSWindowBecameOccluded = 913,

	kCGSServerWindowDidCreate = 1000,
	kCGSServerWindowWillTerminate = 1001,
	kCGSServerWindowOrderDidChange = 1002,
	kCGSServerWindowDidTerminate = 1003,
	
	kCGSWindowWasMovedByDockEvent = 1205,
	kCGSWindowWasResizedByDockEvent = 1207,
	kCGSWindowDidBecomeManagedByDockEvent = 1208,
	
	kCGSServerMenuBarCreated = 1300,
	kCGSServerHidBackstopMenuBar = 1301,
	kCGSServerShowBackstopMenuBar = 1302,
	kCGSServerMenuBarDrawingStyleChanged = 1303,
	kCGSServerPersistentAppsRegistered = 1304,
	kCGSServerPersistentCheckinComplete = 1305,

	kCGSPackagesWorkspacesDisabled = 1306,
	kCGSPackagesWorkspacesEnabled = 1307,
	kCGSPackagesStatusBarSpaceChanged = 1308,

	kCGSWorkspaceWillChange = 1400,
	kCGSWorkspaceDidChange = 1401,
	kCGSWorkspaceWindowIsViewable = 1402,
	kCGSWorkspaceWindowIsNotViewable = 1403,
	kCGSWorkspaceWindowDidMove = 1404,
	kCGSWorkspacePrefsDidChange = 1405,
	kCGSWorkspacesWindowDragDidStart = 1411,
	kCGSWorkspacesWindowDragDidEnd = 1412,
	kCGSWorkspacesWindowDragWillEnd = 1413,
	kCGSWorkspacesShowSpaceForProcess = 1414,
	kCGSWorkspacesWindowDidOrderInOnNonCurrentManagedSpacesOnly = 1415,
	kCGSWorkspacesWindowDidOrderOutOnNonCurrentManagedSpaces = 1416,

	kCGSessionConsoleConnect = 1500,
	kCGSessionConsoleDisconnect = 1501,
	kCGSessionRemoteConnect = 1502,
	kCGSessionRemoteDisconnect = 1503,
	kCGSessionLoggedOn = 1504,
	kCGSessionLoggedOff = 1505,
	kCGSessionConsoleWillDisconnect = 1506,
	kCGXWillCreateSession = 1550,
	kCGXDidCreateSession = 1551,
	kCGXWillDestroySession = 1552,
	kCGXDidDestroySession = 1553,
	kCGXWorkspaceConnected = 1554,
	kCGXSessionReleased = 1555,

	kCGSTransitionDidFinish = 1700,

	kCGXServerDisplayHardwareWillReset = 1800,
	kCGXServerDesktopShapeChanged = 1801,
	kCGXServerDisplayConfigurationChanged = 1802,
	kCGXServerDisplayAcceleratorOffline = 1803,
	kCGXServerDisplayAcceleratorDeactivate = 1804,
} CGSEventType;


#pragma mark - System-Level Event Notification Registration


typedef void (*CGSNotifyProcPtr)(CGSEventType type, void *data, unsigned int dataLength, void *userData);

/// Registers a function to receive notifications for system-wide events.
CG_EXTERN CGError CGSRegisterNotifyProc(CGSNotifyProcPtr proc, CGSEventType type, void *userData);

/// Unregisters a function that was registered to receive notifications for system-wide events.
CG_EXTERN CGError CGSRemoveNotifyProc(CGSNotifyProcPtr proc, CGSEventType type, void *userData);


#pragma mark - Application-Level Event Notification Registration


typedef void (*CGConnectionNotifyProc)(CGSEventType type, CGSNotificationData notificationData, size_t dataLength, CGSNotificationArg userParameter, CGSConnectionID);

/// Registers a function to receive notifications for connection-level events.
CG_EXTERN CGError CGSRegisterConnectionNotifyProc(CGSConnectionID cid, CGConnectionNotifyProc function, CGSEventType event, void *userData);

/// Unregisters a function that was registered to receive notifications for connection-level events.
CG_EXTERN CGError CGSRemoveConnectionNotifyProc(CGSConnectionID cid, CGConnectionNotifyProc function, CGSEventType event, void *userData);


typedef struct _CGSEventRecord {
	CGSEventRecordVersion major; /*0x0*/
	CGSEventRecordVersion minor; /*0x2*/
	CGSByteCount length;         /*0x4*/ /* Length of complete event record */
	CGSEventType type;           /*0x8*/ /* An event type from above */
	CGPoint location;            /*0x10*/ /* Base coordinates (global), from upper-left */
	CGPoint windowLocation;      /*0x20*/ /* Coordinates relative to window */
	CGSEventRecordTime time;     /*0x30*/ /* nanoseconds since startup */
	CGSEventFlag flags;         /* key state flags */
	CGWindowID window;         /* window number of assigned window */
	CGSConnectionID connection; /* connection the event came from */
	struct __CGEventSourceData {
		int source;
		unsigned int sourceUID;
		unsigned int sourceGID;
		unsigned int flags;
		unsigned long long userData;
		unsigned int sourceState;
		unsigned short localEventSuppressionInterval;
		unsigned char suppressionIntervalFlags;
		unsigned char remoteMouseDragFlags;
		unsigned long long serviceID;
	} eventSource;
	struct _CGEventProcess {
		int pid;
		unsigned int psnHi;
		unsigned int psnLo;
		unsigned int targetID;
		unsigned int flags;
	} eventProcess;
	NXEventData eventData;
	SInt32 _padding[4];
	void *ioEventData;
	unsigned short _field16;
	unsigned short _field17;
	struct _CGSEventAppendix {
		unsigned short windowHeight;
		unsigned short mainDisplayHeight;
		unsigned short *unicodePayload;
		unsigned int eventOwner;
		unsigned char passedThrough;
	} *appendix;
	unsigned int _field18;
	bool passedThrough;
	CFDataRef data;
} CGSEventRecord;

/// Gets the event record for a given `CGEventRef`.
///
/// For Carbon events, use `GetEventPlatformEventRecord`.
CG_EXTERN CGError CGEventGetEventRecord(CGEventRef event, CGSEventRecord *outRecord, size_t recSize);

/// Gets the main event port for the connection ID.
CG_EXTERN OSErr CGSGetEventPort(CGSConnectionID identifier, mach_port_t *port);

/// Getter and setter for the background event mask.
CG_EXTERN void CGSGetBackgroundEventMask(CGSConnectionID cid, int *outMask);
CG_EXTERN CGError CGSSetBackgroundEventMask(CGSConnectionID cid, int mask);


/// Returns	`True` if the application has been deemed unresponsive for a certain amount of time.
CG_EXTERN bool CGSEventIsAppUnresponsive(CGSConnectionID cid, const ProcessSerialNumber *psn);

/// Sets the amount of time it takes for an application to be considered unresponsive.
CG_EXTERN CGError CGSEventSetAppIsUnresponsiveNotificationTimeout(CGSConnectionID cid, double theTime);

#pragma mark input

// Gets and sets the status of secure input. When secure input is enabled, keyloggers, etc are harder to do.
CG_EXTERN bool CGSIsSecureEventInputSet(void);
CG_EXTERN CGError CGSSetSecureEventInput(CGSConnectionID cid, bool useSecureInput);

#endif /* CGS_EVENT_INTERNAL_H */



---
File: /CGSHotKeys.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 *
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 *
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 *
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 *
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_HOTKEYS_INTERNAL_H
#define CGS_HOTKEYS_INTERNAL_H

#include "CGSConnection.h"

/// The system defines a limited number of "symbolic" hot keys that are remembered system-wide.  The
/// original intent is to have a common registry for the action of function keys and numerous
/// other event-generating system gestures.
typedef enum {
	// full keyboard access hotkeys
	kCGSHotKeyToggleFullKeyboardAccess = 12,
	kCGSHotKeyFocusMenubar = 7,
	kCGSHotKeyFocusDock = 8,
	kCGSHotKeyFocusNextGlobalWindow = 9,
	kCGSHotKeyFocusToolbar = 10,
	kCGSHotKeyFocusFloatingWindow = 11,
	kCGSHotKeyFocusApplicationWindow = 27,
	kCGSHotKeyFocusNextControl = 13,
	kCGSHotKeyFocusDrawer = 51,
	kCGSHotKeyFocusStatusItems = 57,

	// screenshot hotkeys
	kCGSHotKeyScreenshot = 28,
	kCGSHotKeyScreenshotToClipboard = 29,
	kCGSHotKeyScreenshotRegion = 30,
	kCGSHotKeyScreenshotRegionToClipboard = 31,

	// universal access
	kCGSHotKeyToggleZoom = 15,
	kCGSHotKeyZoomOut = 19,
	kCGSHotKeyZoomIn = 17,
	kCGSHotKeyZoomToggleSmoothing = 23,
	kCGSHotKeyIncreaseContrast = 25,
	kCGSHotKeyDecreaseContrast = 26,
	kCGSHotKeyInvertScreen = 21,
	kCGSHotKeyToggleVoiceOver = 59,

	// Dock
	kCGSHotKeyToggleDockAutohide = 52,
	kCGSHotKeyExposeAllWindows = 32,
	kCGSHotKeyExposeAllWindowsSlow = 34,
	kCGSHotKeyExposeApplicationWindows = 33,
	kCGSHotKeyExposeApplicationWindowsSlow = 35,
	kCGSHotKeyExposeDesktop = 36,
	kCGSHotKeyExposeDesktopsSlow = 37,
	kCGSHotKeyDashboard = 62,
	kCGSHotKeyDashboardSlow = 63,

	// spaces (Leopard and later)
	kCGSHotKeySpaces = 75,
	kCGSHotKeySpacesSlow = 76,
	// 77 - fn F7 (disabled)
	// 78 - ⇧fn F7 (disabled)
	kCGSHotKeySpaceLeft = 79,
	kCGSHotKeySpaceLeftSlow = 80,
	kCGSHotKeySpaceRight = 81,
	kCGSHotKeySpaceRightSlow = 82,
	kCGSHotKeySpaceDown = 83,
	kCGSHotKeySpaceDownSlow = 84,
	kCGSHotKeySpaceUp = 85,
	kCGSHotKeySpaceUpSlow = 86,

	// input
	kCGSHotKeyToggleCharacterPallette = 50,
	kCGSHotKeySelectPreviousInputSource = 60,
	kCGSHotKeySelectNextInputSource = 61,

	// Spotlight
	kCGSHotKeySpotlightSearchField = 64,
	kCGSHotKeySpotlightWindow = 65,

	kCGSHotKeyToggleFrontRow = 73,
	kCGSHotKeyLookUpWordInDictionary = 70,
	kCGSHotKeyHelp = 98,

	// displays - not verified
	kCGSHotKeyDecreaseDisplayBrightness = 53,
	kCGSHotKeyIncreaseDisplayBrightness = 54,
} CGSSymbolicHotKey;

/// The possible operating modes of a hot key.
typedef enum {
	/// All hot keys are enabled app-wide.
	kCGSGlobalHotKeyEnable							= 0,
	/// All hot keys are disabled app-wide.
	kCGSGlobalHotKeyDisable							= 1,
	/// Hot keys are disabled app-wide, but exceptions are made for Accessibility.
	kCGSGlobalHotKeyDisableAllButUniversalAccess	= 2,
} CGSGlobalHotKeyOperatingMode;

/// Options representing device-independent bits found in event modifier flags:
typedef enum : unsigned int {
	/// Set if Caps Lock key is pressed.
	kCGSAlphaShiftKeyMask = 1 << 16,
	/// Set if Shift key is pressed.
	kCGSShiftKeyMask      = 1 << 17,
	/// Set if Control key is pressed.
	kCGSControlKeyMask    = 1 << 18,
	/// Set if Option or Alternate key is pressed.
	kCGSAlternateKeyMask  = 1 << 19,
	/// Set if Command key is pressed.
	kCGSCommandKeyMask    = 1 << 20,
	/// Set if any key in the numeric keypad is pressed.
	kCGSNumericPadKeyMask = 1 << 21,
	/// Set if the Help key is pressed.
	kCGSHelpKeyMask       = 1 << 22,
	/// Set if any function key is pressed.
	kCGSFunctionKeyMask   = 1 << 23,
	/// Used to retrieve only the device-independent modifier flags, allowing applications to mask
	/// off the device-dependent modifier flags, including event coalescing information.
	kCGSDeviceIndependentModifierFlagsMask = 0xffff0000U
} CGSModifierFlags;


#pragma mark - Symbolic Hot Keys


/// Gets the current global hot key operating mode for the application.
CG_EXTERN CGError CGSGetGlobalHotKeyOperatingMode(CGSConnectionID cid, CGSGlobalHotKeyOperatingMode *outMode);

/// Sets the current operating mode for the application.
///
/// This function can be used to enable and disable all hot key events on the given connection.
CG_EXTERN CGError CGSSetGlobalHotKeyOperatingMode(CGSConnectionID cid, CGSGlobalHotKeyOperatingMode mode);


#pragma mark - Symbol Hot Key Properties


/// Returns whether the symbolic hot key represented by the given UID is enabled.
CG_EXTERN bool CGSIsSymbolicHotKeyEnabled(CGSSymbolicHotKey hotKey);

/// Sets whether the symbolic hot key represented by the given UID is enabled.
CG_EXTERN CGError CGSSetSymbolicHotKeyEnabled(CGSSymbolicHotKey hotKey, bool isEnabled);

/// Returns the values the symbolic hot key represented by the given UID is configured with.
CG_EXTERN CGError CGSGetSymbolicHotKeyValue(CGSSymbolicHotKey hotKey, unichar *outKeyEquivalent, unichar *outVirtualKeyCode, CGSModifierFlags *outModifiers);


#pragma mark - Custom Hot Keys


/// Sets the value of the configuration options for the hot key represented by the given UID,
/// creating a hot key if needed.
///
/// If the given UID is unique and not in use, a hot key will be instantiated for you under it.
CG_EXTERN void CGSSetHotKey(CGSConnectionID cid, int uid, unichar options, unichar key, CGSModifierFlags modifierFlags);

/// Functions like `CGSSetHotKey` but with an exclusion value.
///
/// The exact function of the exclusion value is unknown.  Working theory: It is supposed to be
/// passed the UID of another existing hot key that it supresses.  Why can only one can be passed, tho?
CG_EXTERN void CGSSetHotKeyWithExclusion(CGSConnectionID cid, int uid, unichar options, unichar key, CGSModifierFlags modifierFlags, int exclusion);

/// Returns the value of the configured options for the hot key represented by the given UID.
CG_EXTERN bool CGSGetHotKey(CGSConnectionID cid, int uid, unichar *options, unichar *key, CGSModifierFlags *modifierFlags);

/// Removes a previously created hot key.
CG_EXTERN void CGSRemoveHotKey(CGSConnectionID cid, int uid);


#pragma mark - Custom Hot Key Properties


/// Returns whether the hot key represented by the given UID is enabled.
CG_EXTERN BOOL CGSIsHotKeyEnabled(CGSConnectionID cid, int uid);

/// Sets whether the hot key represented by the given UID is enabled.
CG_EXTERN void CGSSetHotKeyEnabled(CGSConnectionID cid, int uid, bool enabled);

#endif /* CGS_HOTKEYS_INTERNAL_H */



---
File: /CGSInternal.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_INTERNAL_API_H
#define CGS_INTERNAL_API_H

#include <Carbon/Carbon.h>
#include <ApplicationServices/ApplicationServices.h>

// WARNING: CGSInternal contains PRIVATE FUNCTIONS and should NOT BE USED in shipping applications!

#include "CGSAccessibility.h"
#include "CGSCIFilter.h"
#include "CGSConnection.h"
#include "CGSCursor.h"
#include "CGSDebug.h"
#include "CGSDevice.h"
#include "CGSDisplays.h"
#include "CGSEvent.h"
#include "CGSHotKeys.h"
#include "CGSMisc.h"
#include "CGSRegion.h"
#include "CGSSession.h"
#include "CGSSpace.h"
#include "CGSSurface.h"
#include "CGSTile.h"
#include "CGSTransitions.h"
#include "CGSWindow.h"
#include "CGSWorkspace.h"

#endif /* CGS_INTERNAL_API_H */



---
File: /CGSMisc.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_MISC_INTERNAL_H
#define CGS_MISC_INTERNAL_H

#include "CGSConnection.h"

/// Is someone watching this screen? Applies to Apple's remote desktop only?
CG_EXTERN bool CGSIsScreenWatcherPresent(void);

#pragma mark - Error Logging

/// Logs an error and returns `err`.
CG_EXTERN CGError CGSGlobalError(CGError err, const char *msg);

/// Logs an error and returns `err`.
CG_EXTERN CGError CGSGlobalErrorv(CGError err, const char *msg, ...);

/// Gets the error message for an error code.
CG_EXTERN char *CGSErrorString(CGError error);

#endif /* CGS_MISC_INTERNAL_H */



---
File: /CGSRegion.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_REGION_INTERNAL_H
#define CGS_REGION_INTERNAL_H

typedef CFTypeRef CGSRegionRef;
typedef CFTypeRef CGSRegionEnumeratorRef;


#pragma mark - Region Lifecycle


/// Creates a region from a `CGRect`.
CG_EXTERN CGError CGSNewRegionWithRect(const CGRect *rect, CGSRegionRef *outRegion);

/// Creates a region from a list of `CGRect`s.
CG_EXTERN CGError CGSNewRegionWithRectList(const CGRect *rects, int rectCount, CGSRegionRef *outRegion);

/// Creates a new region from a QuickDraw region.
CG_EXTERN CGError CGSNewRegionWithQDRgn(RgnHandle region, CGSRegionRef *outRegion);

/// Creates an empty region.
CG_EXTERN CGError CGSNewEmptyRegion(CGSRegionRef *outRegion);

/// Releases a region.
CG_EXTERN CGError CGSReleaseRegion(CGSRegionRef region);


#pragma mark - Creating Complex Regions


/// Created a new region by changing the origin an existing one.
CG_EXTERN CGError CGSOffsetRegion(CGSRegionRef region, CGFloat offsetLeft, CGFloat offsetTop, CGSRegionRef *outRegion);

/// Creates a new region by copying an existing one.
CG_EXTERN CGError CGSCopyRegion(CGSRegionRef region, CGSRegionRef *outRegion);

/// Creates a new region by combining two regions together.
CG_EXTERN CGError CGSUnionRegion(CGSRegionRef region1, CGSRegionRef region2, CGSRegionRef *outRegion);

/// Creates a new region by combining a region and a rect.
CG_EXTERN CGError CGSUnionRegionWithRect(CGSRegionRef region, CGRect *rect, CGSRegionRef *outRegion);

/// Creates a region by XORing two regions together.
CG_EXTERN CGError CGSXorRegion(CGSRegionRef region1, CGSRegionRef region2, CGSRegionRef *outRegion);

/// Creates a `CGRect` from a region.
CG_EXTERN CGError CGSGetRegionBounds(CGSRegionRef region, CGRect *outRect);

/// Creates a rect from the difference of two regions.
CG_EXTERN CGError CGSDiffRegion(CGSRegionRef region1, CGSRegionRef region2, CGSRegionRef *outRegion);


#pragma mark - Comparing Regions


/// Determines if two regions are equal.
CG_EXTERN bool CGSRegionsEqual(CGSRegionRef region1, CGSRegionRef region2);

/// Determines if a region is inside of a region.
CG_EXTERN bool CGSRegionInRegion(CGSRegionRef region1, CGSRegionRef region2);

/// Determines if a region intersects a region.
CG_EXTERN bool CGSRegionIntersectsRegion(CGSRegionRef region1, CGSRegionRef region2);

/// Determines if a rect intersects a region.
CG_EXTERN bool CGSRegionIntersectsRect(CGSRegionRef obj, const CGRect *rect);


#pragma mark - Checking for Membership


/// Determines if a point in a region.
CG_EXTERN bool CGSPointInRegion(CGSRegionRef region, const CGPoint *point);

/// Determines if a rect is in a region.
CG_EXTERN bool CGSRectInRegion(CGSRegionRef region, const CGRect *rect);


#pragma mark - Checking Region Characteristics


/// Determines if the region is empty.
CG_EXTERN bool CGSRegionIsEmpty(CGSRegionRef region);

/// Determines if the region is rectangular.
CG_EXTERN bool CGSRegionIsRectangular(CGSRegionRef region);


#pragma mark - Region Enumerators


/// Gets the enumerator for a region.
CG_EXTERN CGSRegionEnumeratorRef CGSRegionEnumerator(CGSRegionRef region);

/// Releases a region enumerator.
CG_EXTERN void CGSReleaseRegionEnumerator(CGSRegionEnumeratorRef enumerator);

/// Gets the next rect of a region.
CG_EXTERN CGRect *CGSNextRect(CGSRegionEnumeratorRef enumerator);


/// DOCUMENTATION PENDING */
CG_EXTERN CGError CGSFetchDirtyScreenRegion(CGSConnectionID cid, CGSRegionRef *outDirtyRegion);

#endif /* CGS_REGION_INTERNAL_H */



---
File: /CGSSession.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_SESSION_INTERNAL_H
#define CGS_SESSION_INTERNAL_H

#include "CGSInternal.h"

typedef int CGSSessionID;

/// Creates a new "blank" login session.
///
/// Switches to the LoginWindow. This does NOT check to see if fast user switching is enabled!
CG_EXTERN CGError CGSCreateLoginSession(CGSSessionID *outSession);

/// Releases a session.
CG_EXTERN CGError CGSReleaseSession(CGSSessionID session);

/// Gets information about the current login session.
///
/// As of OS X 10.6, the following keys appear in this dictionary:
///
///     kCGSSessionGroupIDKey		: CFNumberRef
///     kCGSSessionOnConsoleKey		: CFBooleanRef
///     kCGSSessionIDKey			: CFNumberRef
///     kCGSSessionUserNameKey		: CFStringRef
///     kCGSessionLongUserNameKey	: CFStringRef
///     kCGSessionLoginDoneKey		: CFBooleanRef
///     kCGSSessionUserIDKey		: CFNumberRef
///     kCGSSessionSecureInputPID	: CFNumberRef
CG_EXTERN CFDictionaryRef CGSCopyCurrentSessionDictionary(void);

/// Gets a list of session dictionaries.
///
/// Each session dictionary is in the format returned by `CGSCopyCurrentSessionDictionary`.
CG_EXTERN CFArrayRef CGSCopySessionList(void);

#endif /* CGS_SESSION_INTERNAL_H */



---
File: /CGSSpace.h
---

//
//  CGSSpace.h
//  CGSInternal
//
//  Created by Robert Widmann on 9/14/13.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_SPACE_INTERNAL_H
#define CGS_SPACE_INTERNAL_H

#include "CGSConnection.h"
#include "CGSRegion.h"

typedef size_t CGSSpaceID;

/// Representations of the possible types of spaces the system can create.
typedef enum {
	/// User-created desktop spaces.
	CGSSpaceTypeUser		= 0,
	/// Fullscreen spaces.
	CGSSpaceTypeFullscreen	= 1,
	/// System spaces e.g. Dashboard.
	CGSSpaceTypeSystem		= 2,
} CGSSpaceType;

/// Flags that can be applied to queries for spaces.
typedef enum {
	CGSSpaceIncludesCurrent = 1 << 0,
	CGSSpaceIncludesOthers	= 1 << 1,
	CGSSpaceIncludesUser	= 1 << 2,

	CGSSpaceVisible			= 1 << 16,

	kCGSCurrentSpaceMask = CGSSpaceIncludesUser | CGSSpaceIncludesCurrent,
	kCGSOtherSpacesMask = CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent,
	kCGSAllSpacesMask = CGSSpaceIncludesUser | CGSSpaceIncludesOthers | CGSSpaceIncludesCurrent,
	KCGSAllVisibleSpacesMask = CGSSpaceVisible | kCGSAllSpacesMask,
} CGSSpaceMask;

typedef enum {
	/// Each display manages a single contiguous space.
	kCGSPackagesSpaceManagementModeNone = 0,
	/// Each display manages a separate stack of spaces.
	kCGSPackagesSpaceManagementModePerDesktop = 1,
} CGSSpaceManagementMode;

#pragma mark - Space Lifecycle


/// Creates a new space with the given options dictionary.
///
/// Valid keys are:
///
///     "type": CFNumberRef
///     "uuid": CFStringRef
CG_EXTERN CGSSpaceID CGSSpaceCreate(CGSConnectionID cid, void *null, CFDictionaryRef options);

/// Removes and destroys the space corresponding to the given space ID.
CG_EXTERN void CGSSpaceDestroy(CGSConnectionID cid, CGSSpaceID sid);


#pragma mark - Configuring Spaces


/// Get and set the human-readable name of a space.
CG_EXTERN CFStringRef CGSSpaceCopyName(CGSConnectionID cid, CGSSpaceID sid);
CG_EXTERN CGError CGSSpaceSetName(CGSConnectionID cid, CGSSpaceID sid, CFStringRef name);

/// Get and set the affine transform of a space.
CG_EXTERN CGAffineTransform CGSSpaceGetTransform(CGSConnectionID cid, CGSSpaceID space);
CG_EXTERN void CGSSpaceSetTransform(CGSConnectionID cid, CGSSpaceID space, CGAffineTransform transform);

/// Gets and sets the region the space occupies.  You are responsible for releasing the region object.
CG_EXTERN void CGSSpaceSetShape(CGSConnectionID cid, CGSSpaceID space, CGSRegionRef shape);
CG_EXTERN CGSRegionRef CGSSpaceCopyShape(CGSConnectionID cid, CGSSpaceID space);



#pragma mark - Space Properties


/// Copies and returns a region the space occupies.  You are responsible for releasing the region object.
CG_EXTERN CGSRegionRef CGSSpaceCopyManagedShape(CGSConnectionID cid, CGSSpaceID sid);

/// Gets the type of a space.
CG_EXTERN CGSSpaceType CGSSpaceGetType(CGSConnectionID cid, CGSSpaceID sid);

/// Gets the current space management mode.
///
/// This method reflects whether the “Displays have separate Spaces” option is 
/// enabled in Mission Control system preference. You might use the return value
/// to determine how to present your app when in fullscreen mode.
CG_EXTERN CGSSpaceManagementMode CGSGetSpaceManagementMode(CGSConnectionID cid) AVAILABLE_MAC_OS_X_VERSION_10_9_AND_LATER;

/// Sets the current space management mode.
CG_EXTERN CGError CGSSetSpaceManagementMode(CGSConnectionID cid, CGSSpaceManagementMode mode) AVAILABLE_MAC_OS_X_VERSION_10_9_AND_LATER;

#pragma mark - Global Space Properties


/// Gets the ID of the space currently visible to the user.
CG_EXTERN CGSSpaceID CGSGetActiveSpace(CGSConnectionID cid);

/// Returns an array of PIDs of applications that have ownership of a given space.
CG_EXTERN CFArrayRef CGSSpaceCopyOwners(CGSConnectionID cid, CGSSpaceID sid);

/// Returns an array of all space IDs.
CG_EXTERN CFArrayRef CGSCopySpaces(CGSConnectionID cid, CGSSpaceMask mask);

/// Given an array of window numbers, returns the IDs of the spaces those windows lie on.
CG_EXTERN CFArrayRef CGSCopySpacesForWindows(CGSConnectionID cid, CGSSpaceMask mask, CFArrayRef windowIDs);


#pragma mark - Space-Local State


/// Connection-local data in a given space.
CG_EXTERN CFDictionaryRef CGSSpaceCopyValues(CGSConnectionID cid, CGSSpaceID space);
CG_EXTERN CGError CGSSpaceSetValues(CGSConnectionID cid, CGSSpaceID sid, CFDictionaryRef values);
CG_EXTERN CGError CGSSpaceRemoveValuesForKeys(CGSConnectionID cid, CGSSpaceID sid, CFArrayRef values);


#pragma mark - Displaying Spaces


/// Given an array of space IDs, each space is shown to the user.
CG_EXTERN void CGSShowSpaces(CGSConnectionID cid, CFArrayRef spaces);

/// Given an array of space IDs, each space is hidden from the user.
CG_EXTERN void CGSHideSpaces(CGSConnectionID cid, CFArrayRef spaces);

/// Given an array of window numbers and an array of space IDs, adds each window to each space.
CG_EXTERN void CGSAddWindowsToSpaces(CGSConnectionID cid, CFArrayRef windows, CFArrayRef spaces);

/// Given an array of window numbers and an array of space IDs, removes each window from each space.
CG_EXTERN void CGSRemoveWindowsFromSpaces(CGSConnectionID cid, CFArrayRef windows, CFArrayRef spaces);

CG_EXTERN CFStringRef kCGSPackagesMainDisplayIdentifier;

/// Changes the active space for a given display.
CG_EXTERN void CGSManagedDisplaySetCurrentSpace(CGSConnectionID cid, CFStringRef display, CGSSpaceID space);

#endif /// CGS_SPACE_INTERNAL_H */




---
File: /CGSSurface.h
---

//
//  CGSSurface.h
//	CGSInternal
//
//  Created by Robert Widmann on 9/14/13.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_SURFACE_INTERNAL_H
#define CGS_SURFACE_INTERNAL_H

#include "CGSWindow.h"

typedef int CGSSurfaceID;


#pragma mark - Surface Lifecycle


/// Adds a drawable surface to a window.
CG_EXTERN CGError CGSAddSurface(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID *outSID);

/// Removes a drawable surface from a window.
CG_EXTERN CGError CGSRemoveSurface(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid);

/// Binds a CAContext to a surface.
///
/// Pass ctx the result of invoking -[CAContext contextId].
CG_EXTERN CGError CGSBindSurface(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid, int x, int y, unsigned int ctx);

#pragma mark - Surface Properties


/// Sets the bounds of a surface.
CG_EXTERN CGError CGSSetSurfaceBounds(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid, CGRect bounds);

/// Gets the smallest rectangle a surface's frame fits in.
CG_EXTERN CGError CGSGetSurfaceBounds(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid, CGFloat *bounds);

/// Sets the opacity of the surface
CG_EXTERN CGError CGSSetSurfaceOpacity(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid, bool isOpaque);

/// Sets a surface's color space.
CG_EXTERN CGError CGSSetSurfaceColorSpace(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID surface, CGColorSpaceRef colorSpace);

/// Tunes a number of properties the Window Server uses when rendering a layer-backed surface.
CG_EXTERN CGError CGSSetSurfaceLayerBackingOptions(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID surface, CGFloat flattenDelay, CGFloat decelerationDelay, CGFloat discardDelay);

/// Sets the order of a surface relative to another surface.
CG_EXTERN CGError CGSOrderSurface(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID surface, CGSSurfaceID otherSurface, int place);

/// Currently does nothing.
CG_EXTERN CGError CGSSetSurfaceBackgroundBlur(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid, CGFloat blur) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

/// Sets the drawing resolution of the surface.
CG_EXTERN CGError CGSSetSurfaceResolution(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID sid, CGFloat scale) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;


#pragma mark - Window Surface Properties


/// Gets the count of all drawable surfaces on a window.
CG_EXTERN CGError CGSGetSurfaceCount(CGSConnectionID cid, CGWindowID wid, int *outCount);

/// Gets a list of surfaces owned by a window.
CG_EXTERN CGError CGSGetSurfaceList(CGSConnectionID cid, CGWindowID wid, int countIds, CGSSurfaceID *ids, int *outCount);


#pragma mark - Drawing Surfaces


/// Flushes a surface to its window.
CG_EXTERN CGError CGSFlushSurface(CGSConnectionID cid, CGWindowID wid, CGSSurfaceID surface, int param);

#endif /* CGS_SURFACE_INTERNAL_H */



---
File: /CGSTile.h
---

//
//  CGSTile.h
//  NUIKit
//
//  Created by Robert Widmann on 10/9/15.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_TILE_INTERNAL_H
#define CGS_TILE_INTERNAL_H

#include "CGSSurface.h"

typedef size_t CGSTileID;


#pragma mark - Proposed Tile Properties


/// Returns true if the space ID and connection admit the creation of a new tile.
CG_EXTERN bool CGSSpaceCanCreateTile(CGSConnectionID cid, CGSSpaceID sid) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

/// Returns the recommended size for a tile that could be added to the given space.
CG_EXTERN CGError CGSSpaceGetSizeForProposedTile(CGSConnectionID cid, CGSSpaceID sid, CGSize *outSize) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;


#pragma mark - Tile Creation


/// Creates a new tile ID in the given space.
CG_EXTERN CGError CGSSpaceCreateTile(CGSConnectionID cid, CGSSpaceID sid, CGSTileID *outTID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;


#pragma mark - Tile Spaces


/// Returns an array of CFNumberRefs of CGSSpaceIDs.
CG_EXTERN CFArrayRef CGSSpaceCopyTileSpaces(CGSConnectionID cid, CGSSpaceID sid) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;


#pragma mark - Tile Properties


/// Returns the size of the inter-tile spacing between tiles in the given space ID.
CG_EXTERN CGFloat CGSSpaceGetInterTileSpacing(CGSConnectionID cid, CGSSpaceID sid) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;
/// Sets the size of the inter-tile spacing for the given space ID.
CG_EXTERN CGError CGSSpaceSetInterTileSpacing(CGSConnectionID cid, CGSSpaceID sid, CGFloat spacing) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

/// Gets the space ID for the given tile space.
CG_EXTERN CGSSpaceID CGSTileSpaceResizeRecordGetSpaceID(CGSSpaceID sid) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;
/// Gets the space ID for the parent of the given tile space.
CG_EXTERN CGSSpaceID CGSTileSpaceResizeRecordGetParentSpaceID(CGSSpaceID sid) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

/// Returns whether the current tile space is being resized.
CG_EXTERN bool CGSTileSpaceResizeRecordIsLiveResizing(CGSSpaceID sid) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

///
CG_EXTERN CGSTileID CGSTileOwnerChangeRecordGetTileID(CGSConnectionID ownerID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;
///
CG_EXTERN CGSSpaceID CGSTileOwnerChangeRecordGetManagedSpaceID(CGSConnectionID ownerID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

///
CG_EXTERN CGSTileID CGSTileEvictionRecordGetTileID(CGSConnectionID ownerID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;
///
CG_EXTERN CGSSpaceID CGSTileEvictionRecordGetManagedSpaceID(CGSConnectionID ownerID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

///
CG_EXTERN CGSSpaceID CGSTileOwnerChangeRecordGetNewOwner(CGSConnectionID ownerID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;
///
CG_EXTERN CGSSpaceID CGSTileOwnerChangeRecordGetOldOwner(CGSConnectionID ownerID) AVAILABLE_MAC_OS_X_VERSION_10_11_AND_LATER;

#endif /* CGS_TILE_INTERNAL_H */



---
File: /CGSTransitions.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_TRANSITIONS_INTERNAL_H
#define CGS_TRANSITIONS_INTERNAL_H

#include "CGSConnection.h"

typedef enum {
	/// No animation is performed during the transition.
	kCGSTransitionNone,
	/// The window's content fades as it becomes visible or hidden.
	kCGSTransitionFade,
	/// The window's content zooms in or out as it becomes visible or hidden.
	kCGSTransitionZoom,
	/// The window's content is revealed gradually in the direction specified by the transition subtype.
	kCGSTransitionReveal,
	/// The window's content slides in or out along the direction specified by the transition subtype.
	kCGSTransitionSlide,
	///
	kCGSTransitionWarpFade,
	kCGSTransitionSwap,
	/// The window's content is aligned to the faces of a cube and rotated in or out along the
	/// direction specified by the transition subtype.
	kCGSTransitionCube,
	///
	kCGSTransitionWarpSwitch,
	/// The window's content is flipped along its midpoint like a page being turned over along the
	/// direction specified by the transition subtype.
	kCGSTransitionFlip
} CGSTransitionType;

typedef enum {
	/// Directions bits for the transition. Some directions don't apply to some transitions.
	kCGSTransitionDirectionLeft		= 1 << 0,
	kCGSTransitionDirectionRight	= 1 << 1,
	kCGSTransitionDirectionDown		= 1 << 2,
	kCGSTransitionDirectionUp		=	1 << 3,
	kCGSTransitionDirectionCenter	= 1 << 4,
	
	/// Reverses a transition. Doesn't apply for all transitions.
	kCGSTransitionFlagReversed		= 1 << 5,
	
	/// Ignore the background color and only transition the window.
	kCGSTransitionFlagTransparent	= 1 << 7,
} CGSTransitionFlags;

typedef struct CGSTransitionSpec {
	int version; // always set to zero
	CGSTransitionType type;
	CGSTransitionFlags options;
	CGWindowID wid; /* 0 means a full screen transition. */
	CGFloat *backColor; /* NULL means black. */
} *CGSTransitionSpecRef;

/// Creates a new transition from a `CGSTransitionSpec`.
CG_EXTERN CGError CGSNewTransition(CGSConnectionID cid, const CGSTransitionSpecRef spec, CGSTransitionID *outTransition);

/// Invokes a transition asynchronously. Note that `duration` is in seconds.
CG_EXTERN CGError CGSInvokeTransition(CGSConnectionID cid, CGSTransitionID transition, CGFloat duration);

/// Releases a transition.
CG_EXTERN CGError CGSReleaseTransition(CGSConnectionID cid, CGSTransitionID transition);

#endif /* CGS_TRANSITIONS_INTERNAL_H */



---
File: /CGSWindow.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_WINDOW_INTERNAL_H
#define CGS_WINDOW_INTERNAL_H

#include "CGSConnection.h"
#include "CGSRegion.h"

typedef CFTypeRef CGSAnimationRef;
typedef CFTypeRef CGSWindowBackdropRef;
typedef struct CGSWarpPoint CGSWarpPoint;

#define kCGSRealMaximumTagSize (sizeof(void *) * 8)

typedef enum {
	kCGSSharingNone,
	kCGSSharingReadOnly,
	kCGSSharingReadWrite
} CGSSharingState;

typedef enum {
	kCGSOrderBelow = -1,
	kCGSOrderOut, /* hides the window */
	kCGSOrderAbove,
	kCGSOrderIn /* shows the window */
} CGSWindowOrderingMode;

typedef enum {
	kCGSBackingNonRetianed,
	kCGSBackingRetained,
	kCGSBackingBuffered,
} CGSBackingType;

typedef enum {
	CGSWindowSaveWeightingDontReuse,
	CGSWindowSaveWeightingTopLeft,
	CGSWindowSaveWeightingTopRight,
	CGSWindowSaveWeightingBottomLeft,
	CGSWindowSaveWeightingBottomRight,
	CGSWindowSaveWeightingClip,
} CGSWindowSaveWeighting;
typedef enum : int {
	// Lo bits
	
	/// The window appears in the default style of OS X windows.  "Document" is most likely a
	/// historical name.
	kCGSDocumentWindowTagBit						= 1 << 0,
	/// The window appears floating over other windows.  This mask is often combined with other
	/// non-activating bits to enable floating panels.
	kCGSFloatingWindowTagBit						= 1 << 1,
	
	/// Disables the window's badging when it is minimized into its Dock Tile.
	kCGSDoNotShowBadgeInDockTagBit					= 1 << 2,
	
	/// The window will be displayed without a shadow, and will ignore any given shadow parameters.
	kCGSDisableShadowTagBit							= 1 << 3,
	
	/// Causes the Window Server to resample the window at a higher rate.  While this may lead to an
	/// improvement in the look of the window, it can lead to performance issues.
	kCGSHighQualityResamplingTagBit					= 1 << 4,
	
	/// The window may set the cursor when the application is not active.  Useful for windows that
	/// present controls like editable text fields.
	kCGSSetsCursorInBackgroundTagBit				= 1 << 5,
	
	/// The window continues to operate while a modal run loop has been pushed.
	kCGSWorksWhenModalTagBit						= 1 << 6,
	
	/// The window is anchored to another window.
	kCGSAttachedWindowTagBit						= 1 << 7,

	/// When dragging, the window will ignore any alpha and appear 100% opaque.
	kCGSIgnoreAlphaForDraggingTagBit				= 1 << 8,
	
	/// The window appears transparent to events.  Mouse events will pass through it to the next
	/// eligible responder.  This bit or kCGSOpaqueForEventsTagBit must be exclusively set.
	kCGSIgnoreForEventsTagBit						= 1 << 9,
	/// The window appears opaque to events.  Mouse events will be intercepted by the window when
	/// necessary.  This bit or kCGSIgnoreForEventsTagBit must be exclusively set.
	kCGSOpaqueForEventsTagBit						= 1 << 10,
	
	/// The window appears on all workspaces regardless of where it was created.  This bit is used
	/// for QuickLook panels.
	kCGSOnAllWorkspacesTagBit						= 1 << 11,

	///
	kCGSPointerEventsAvoidCPSTagBit					= 1 << 12,
	
	///
	kCGSKitVisibleTagBit							= 1 << 13,
	
	/// On application deactivation the window disappears from the window list.
	kCGSHideOnDeactivateTagBit						= 1 << 14,
	
	/// When the window appears it will not bring the application to the forefront.
	kCGSAvoidsActivationTagBit						= 1 << 15,
	/// When the window is selected it will not bring the application to the forefront.
	kCGSPreventsActivationTagBit					= 1 << 16,
	
	///
	kCGSIgnoresOptionTagBit							= 1 << 17,
	
	/// The window ignores the window cycling mechanism.
	kCGSIgnoresCycleTagBit							= 1 << 18,
 
	///
	kCGSDefersOrderingTagBit						= 1 << 19,
	
	///
	kCGSDefersActivationTagBit						= 1 << 20,
	
	/// WindowServer will ignore all requests to order this window front.
	kCGSIgnoreAsFrontWindowTagBit					= 1 << 21,
	
	/// The WindowServer will control the movement of the window on the screen using its given
	/// dragging rects.  This enables windows to be movable even when the application stalls.
	kCGSEnableServerSideDragTagBit					= 1 << 22,
	
	///
	kCGSMouseDownEventsGrabbedTagBit				= 1 << 23,
	
	/// The window ignores all requests to hide.
	kCGSDontHideTagBit								= 1 << 24,
	
	///
	kCGSDontDimWindowDisplayTagBit					= 1 << 25,
	
	/// The window converts all pointers, no matter if they are mice or tablet pens, to its pointer
	/// type when they enter the window.
	kCGSInstantMouserWindowTagBit					= 1 << 26,
	
	/// The window appears only on active spaces, and will follow when the user changes said active
	/// space.
	kCGSWindowOwnerFollowsForegroundTagBit			= 1 << 27,
	
	///
	kCGSActivationWindowLevelTagBit					= 1 << 28,
	
	/// The window brings its owning application to the forefront when it is selected.
	kCGSBringOwningApplicationForwardTagBit			= 1 << 29,
	
	/// The window is allowed to appear when over login screen.
	kCGSPermittedBeforeLoginTagBit					= 1 << 30,
	
	/// The window is modal.
	kCGSModalWindowTagBit							= 1 << 31,

	// Hi bits
	
	/// The window draws itself like the dock -the "Magic Mirror".
	kCGSWindowIsMagicMirrorTagBit					= 1 << 1,
	
	///
	kCGSFollowsUserTagBit							= 1 << 2,
	
	///
	kCGSWindowDoesNotCastMirrorReflectionTagBit		= 1 << 3,
	
	///
	kCGSMeshedWindowTagBit							= 1 << 4,
	
	/// Bit is set when CoreDrag has dragged something to the window.
	kCGSCoreDragIsDraggingWindowTagBit				= 1 << 5,
	
	///
	kCGSAvoidsCaptureTagBit							= 1 << 6,
	
	/// The window is ignored for expose and does not change its appearance in any way when it is
	/// activated.
	kCGSIgnoreForExposeTagBit						= 1 << 7,
	
	/// The window is hidden.
	kCGSHiddenTagBit								= 1 << 8,
	
	/// The window is explicitly included in the window cycling mechanism.
	kCGSIncludeInCycleTagBit						= 1 << 9,
	
	/// The window captures gesture events even when the application is not in the foreground.
	kCGSWantGesturesInBackgroundTagBit				= 1 << 10,
	
	/// The window is fullscreen.
	kCGSFullScreenTagBit							= 1 << 11,
	
	///
	kCGSWindowIsMagicZoomTagBit						= 1 << 12,
	
	///
	kCGSSuperStickyTagBit							= 1 << 13,
	
	/// The window is attached to the menu bar.  This is used for NSMenus presented by menu bar
	/// apps.
	kCGSAttachesToMenuBarTagBit						= 1 << 14,
	
	/// The window appears on the menu bar.  This is used for all menu bar items.
	kCGSMergesWithMenuBarTagBit						= 1 << 15,
	
	///
	kCGSNeverStickyTagBit							= 1 << 16,
	
	/// The window appears at the level of the desktop picture.
	kCGSDesktopPictureTagBit						= 1 << 17,
	
	/// When the window is redrawn it moves forward.  Useful for debugging, annoying in practice.
	kCGSOrdersForwardWhenSurfaceFlushedTagBit		= 1 << 18,
	
	/// 
	kCGSDragsMovementGroupParentTagBit				= 1 << 19,
	kCGSNeverFlattenSurfacesDuringSwipesTagBit		= 1 << 20,
	kCGSFullScreenCapableTagBit						= 1 << 21,
	kCGSFullScreenTileCapableTagBit					= 1 << 22,
} CGSWindowTagBit;

struct CGSWarpPoint {
	CGPoint localPoint;
	CGPoint globalPoint;
};


#pragma mark - Creating Windows


/// Creates a new CGSWindow.
///
/// The real window top/left is the sum of the region's top/left and the top/left parameters.
CG_EXTERN CGError CGSNewWindow(CGSConnectionID cid, CGSBackingType backingType, CGFloat left, CGFloat top, CGSRegionRef region, CGWindowID *outWID);

/// Creates a new CGSWindow.
///
/// The real window top/left is the sum of the region's top/left and the top/left parameters.
CG_EXTERN CGError CGSNewWindowWithOpaqueShape(CGSConnectionID cid, CGSBackingType backingType, CGFloat left, CGFloat top, CGSRegionRef region, CGSRegionRef opaqueShape, int unknown, CGSWindowTagBit *tags, int tagSize, CGWindowID *outWID);

/// Releases a CGSWindow.
CG_EXTERN CGError CGSReleaseWindow(CGSConnectionID cid, CGWindowID wid);


#pragma mark - Configuring Windows


/// Gets the value associated with the specified window property as a CoreFoundation object.
CG_EXTERN CGError CGSGetWindowProperty(CGSConnectionID cid, CGWindowID wid, CFStringRef key, CFTypeRef *outValue);
CG_EXTERN CGError CGSSetWindowProperty(CGSConnectionID cid, CGWindowID wid, CFStringRef key, CFTypeRef value);

/// Sets the window's title.
///
/// A window's title and what is displayed on its titlebar are often distinct strings.  The value
/// passed to this method is used to identify the window in spaces.
///
/// Internally this calls `CGSSetWindowProperty(cid, wid, kCGSWindowTitle, title)`.
CG_EXTERN CGError CGSSetWindowTitle(CGSConnectionID cid, CGWindowID wid, CFStringRef title);


/// Returns the window’s alpha value.
CG_EXTERN CGError CGSGetWindowAlpha(CGSConnectionID cid, CGWindowID wid, CGFloat *outAlpha);

/// Sets the window's alpha value.
CG_EXTERN CGError CGSSetWindowAlpha(CGSConnectionID cid, CGWindowID wid, CGFloat alpha);

/// Sets the shape of the window and describes how to redraw if the bounding
/// boxes don't match.
CG_EXTERN CGError CGSSetWindowShapeWithWeighting(CGSConnectionID cid, CGWindowID wid, CGFloat offsetX, CGFloat offsetY, CGSRegionRef shape, CGSWindowSaveWeighting weight);

/// Sets the shape of the window.
CG_EXTERN CGError CGSSetWindowShape(CGSConnectionID cid, CGWindowID wid, CGFloat offsetX, CGFloat offsetY, CGSRegionRef shape);

/// Gets and sets a Boolean value indicating whether the window is opaque.
CG_EXTERN CGError CGSGetWindowOpacity(CGSConnectionID cid, CGWindowID wid, bool *outIsOpaque);
CG_EXTERN CGError CGSSetWindowOpacity(CGSConnectionID cid, CGWindowID wid, bool isOpaque);

/// Gets and sets the window's color space.
CG_EXTERN CGError CGSCopyWindowColorSpace(CGSConnectionID cid, CGWindowID wid, CGColorSpaceRef *outColorSpace);
CG_EXTERN CGError CGSSetWindowColorSpace(CGSConnectionID cid, CGWindowID wid, CGColorSpaceRef colorSpace);

/// Gets and sets the window's clip shape.
CG_EXTERN CGError CGSCopyWindowClipShape(CGSConnectionID cid, CGWindowID wid, CGSRegionRef *outRegion);
CG_EXTERN CGError CGSSetWindowClipShape(CGWindowID wid, CGSRegionRef shape);

/// Gets and sets the window's transform. 
///
///	Severe restrictions are placed on transformation:
/// - Transformation Matrices may only include a singular transform.
/// - Transformations involving scale may not scale upwards past the window's frame.
/// - Transformations involving rotation must be followed by translation or the window will fall offscreen.
CG_EXTERN CGError CGSGetWindowTransform(CGSConnectionID cid, CGWindowID wid, const CGAffineTransform *outTransform);
CG_EXTERN CGError CGSSetWindowTransform(CGSConnectionID cid, CGWindowID wid, CGAffineTransform transform);

/// Gets and sets the window's transform in place. 
///
///	Severe restrictions are placed on transformation:
/// - Transformation Matrices may only include a singular transform.
/// - Transformations involving scale may not scale upwards past the window's frame.
/// - Transformations involving rotation must be followed by translation or the window will fall offscreen.
CG_EXTERN CGError CGSGetWindowTransformAtPlacement(CGSConnectionID cid, CGWindowID wid, const CGAffineTransform *outTransform);
CG_EXTERN CGError CGSSetWindowTransformAtPlacement(CGSConnectionID cid, CGWindowID wid, CGAffineTransform transform);

/// Gets and sets the `CGConnectionID` that owns this window. Only the owner can change most properties of the window.
CG_EXTERN CGError CGSGetWindowOwner(CGSConnectionID cid, CGWindowID wid, CGSConnectionID *outOwner);
CG_EXTERN CGError CGSSetWindowOwner(CGSConnectionID cid, CGWindowID wid, CGSConnectionID owner);

/// Sets the background color of the window.
CG_EXTERN CGError CGSSetWindowAutofillColor(CGSConnectionID cid, CGWindowID wid, CGFloat red, CGFloat green, CGFloat blue);

/// Sets the warp for the window. The mesh maps a local (window) point to a point on screen.
CG_EXTERN CGError CGSSetWindowWarp(CGSConnectionID cid, CGWindowID wid, int warpWidth, int warpHeight, const CGSWarpPoint *warp);

/// Gets or sets whether the Window Server should auto-fill the window's background.
CG_EXTERN CGError CGSGetWindowAutofill(CGSConnectionID cid, CGWindowID wid, bool *outShouldAutoFill);
CG_EXTERN CGError CGSSetWindowAutofill(CGSConnectionID cid, CGWindowID wid, bool shouldAutoFill);

/// Gets and sets the window level for a window.
CG_EXTERN CGError CGSGetWindowLevel(CGSConnectionID cid, CGWindowID wid, CGWindowLevel *outLevel);
CG_EXTERN CGError CGSSetWindowLevel(CGSConnectionID cid, CGWindowID wid, CGWindowLevel level);

/// Gets and sets the sharing state. This determines the level of access other applications have over this window.
CG_EXTERN CGError CGSGetWindowSharingState(CGSConnectionID cid, CGWindowID wid, CGSSharingState *outState);
CG_EXTERN CGError CGSSetWindowSharingState(CGSConnectionID cid, CGWindowID wid, CGSSharingState state);

/// Sets whether this window is ignored in the global window cycle (Control-F4 by default). There is no Get version? */
CG_EXTERN CGError CGSSetIgnoresCycle(CGSConnectionID cid, CGWindowID wid, bool ignoresCycle);


#pragma mark - Managing Window Key State


/// Forces a window to acquire key window status.
CG_EXTERN CGError CGSSetMouseFocusWindow(CGSConnectionID cid, CGWindowID wid);

/// Forces a window to draw with its key appearance.
CG_EXTERN CGError CGSSetWindowHasKeyAppearance(CGSConnectionID cid, CGWindowID wid, bool hasKeyAppearance);

/// Forces a window to be active.
CG_EXTERN CGError CGSSetWindowActive(CGSConnectionID cid, CGWindowID wid, bool isActive);


#pragma mark - Handling Events

/// DEPRECATED: Sets the shape over which the window can capture events in its frame rectangle.
CG_EXTERN CGError CGSSetWindowEventShape(CGSConnectionID cid, CGSBackingType backingType, CGSRegionRef *shape);

/// Gets and sets the window's event mask.
CG_EXTERN CGError CGSGetWindowEventMask(CGSConnectionID cid, CGWindowID wid, CGEventMask *mask);
CG_EXTERN CGError CGSSetWindowEventMask(CGSConnectionID cid, CGWindowID wid, CGEventMask mask);

/// Sets whether a window can recieve mouse events.  If no, events will pass to the next window that can receive the event.
CG_EXTERN CGError CGSSetMouseEventEnableFlags(CGSConnectionID cid, CGWindowID wid, bool shouldEnable);



/// Gets the screen rect for a window.
CG_EXTERN CGError CGSGetScreenRectForWindow(CGSConnectionID cid, CGWindowID wid, CGRect *outRect);


#pragma mark - Drawing Windows

/// Creates a graphics context for the window. 
///
/// Acceptable keys options:
///
/// - CGWindowContextShouldUseCA : CFBooleanRef
CG_EXTERN CGContextRef CGWindowContextCreate(CGSConnectionID cid, CGWindowID wid, CFDictionaryRef options);

/// Flushes a window's buffer to the screen.
CG_EXTERN CGError CGSFlushWindow(CGSConnectionID cid, CGWindowID wid, CGSRegionRef flushRegion);


#pragma mark - Window Order


/// Sets the order of a window.
CG_EXTERN CGError CGSOrderWindow(CGSConnectionID cid, CGWindowID wid, CGSWindowOrderingMode mode, CGWindowID relativeToWID);

CG_EXTERN CGError CGSOrderFrontConditionally(CGSConnectionID cid, CGWindowID wid, bool force);


#pragma mark - Sizing Windows


/// Sets the origin (top-left) of a window.
CG_EXTERN CGError CGSMoveWindow(CGSConnectionID cid, CGWindowID wid, const CGPoint *origin);

/// Sets the origin (top-left) of a window relative to another window's origin.
CG_EXTERN CGError CGSSetWindowOriginRelativeToWindow(CGSConnectionID cid, CGWindowID wid, CGWindowID relativeToWID, CGFloat offsetX, CGFloat offsetY);

/// Sets the frame and position of a window.  Updates are grouped for the sake of animation.
CG_EXTERN CGError CGSMoveWindowWithGroup(CGSConnectionID cid, CGWindowID wid, CGRect *newFrame);

/// Gets the mouse's current location inside the bounds rectangle of the window.
CG_EXTERN CGError CGSGetWindowMouseLocation(CGSConnectionID cid, CGWindowID wid, CGPoint *outPos);


#pragma mark - Window Shadows


/// Sets the shadow information for a window.
///
/// Calls through to `CGSSetWindowShadowAndRimParameters` passing 1 for `flags`.
CG_EXTERN CGError CGSSetWindowShadowParameters(CGSConnectionID cid, CGWindowID wid, CGFloat standardDeviation, CGFloat density, int offsetX, int offsetY);

/// Gets and sets the shadow information for a window.
///
/// Values for `flags` are unknown.  Calls `CGSSetWindowShadowAndRimParametersWithStretch`.
CG_EXTERN CGError CGSSetWindowShadowAndRimParameters(CGSConnectionID cid, CGWindowID wid, CGFloat standardDeviation, CGFloat density, int offsetX, int offsetY, int flags);
CG_EXTERN CGError CGSGetWindowShadowAndRimParameters(CGSConnectionID cid, CGWindowID wid, CGFloat *outStandardDeviation, CGFloat *outDensity, int *outOffsetX, int *outOffsetY, int *outFlags);

/// Sets the shadow information for a window.
CG_EXTERN CGError CGSSetWindowShadowAndRimParametersWithStretch(CGSConnectionID cid, CGWindowID wid, CGFloat standardDeviation, CGFloat density, int offsetX, int offsetY, int stretch_x, int stretch_y, unsigned int flags);

/// Invalidates a window's shadow.
CG_EXTERN CGError CGSInvalidateWindowShadow(CGSConnectionID cid, CGWindowID wid);

/// Sets a window's shadow properties.
///
/// Acceptable keys:
///
/// - com.apple.WindowShadowDensity			- (0.0 - 1.0) Opacity of the window's shadow.
/// - com.apple.WindowShadowRadius			- The radius of the shadow around the window's corners.
/// - com.apple.WindowShadowVerticalOffset	- Vertical offset of the shadow.
/// - com.apple.WindowShadowRimDensity		- (0.0 - 1.0) Opacity of the black rim around the window.
/// - com.apple.WindowShadowRimStyleHard	- Sets a hard black rim around the window.
CG_EXTERN CGError CGSWindowSetShadowProperties(CGWindowID wid, CFDictionaryRef properties);


#pragma mark - Window Lists


/// Gets the number of windows the `targetCID` owns.
CG_EXTERN CGError CGSGetWindowCount(CGSConnectionID cid, CGSConnectionID targetCID, int *outCount);

/// Gets a list of windows owned by `targetCID`.
CG_EXTERN CGError CGSGetWindowList(CGSConnectionID cid, CGSConnectionID targetCID, int count, CGWindowID *list, int *outCount);

/// Gets the number of windows owned by `targetCID` that are on screen.
CG_EXTERN CGError CGSGetOnScreenWindowCount(CGSConnectionID cid, CGSConnectionID targetCID, int *outCount);

/// Gets a list of windows oned by `targetCID` that are on screen.
CG_EXTERN CGError CGSGetOnScreenWindowList(CGSConnectionID cid, CGSConnectionID targetCID, int count, CGWindowID *list, int *outCount);

/// Sets the alpha of a group of windows over a period of time. Note that `duration` is in seconds.
CG_EXTERN CGError CGSSetWindowListAlpha(CGSConnectionID cid, const CGWindowID *widList, int widCount, CGFloat alpha, CGFloat duration);


#pragma mark - Window Activation Regions


/// Sets the shape over which the window can capture events in its frame rectangle.
CG_EXTERN CGError CGSAddActivationRegion(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);

/// Sets the shape over which the window can recieve mouse drag events.
CG_EXTERN CGError CGSAddDragRegion(CGSConnectionID cid, CGWindowID wid, CGSRegionRef region);

/// Removes any shapes over which the window can be dragged.
CG_EXTERN CGError CGSClearDragRegion(CGSConnectionID cid, CGWindowID wid);

CG_EXTERN CGError CGSDragWindowRelativeToMouse(CGSConnectionID cid, CGWindowID wid, CGPoint point);


#pragma mark - Window Animations


/// Creates a Dock-style genie animation that goes from `wid` to `destinationWID`.
CG_EXTERN CGError CGSCreateGenieWindowAnimation(CGSConnectionID cid, CGWindowID wid, CGWindowID destinationWID, CGSAnimationRef *outAnimation);

/// Creates a sheet animation that's used when the parent window is brushed metal. Oddly enough, seems to be the only one used, even if the parent window isn't metal.
CG_EXTERN CGError CGSCreateMetalSheetWindowAnimationWithParent(CGSConnectionID cid, CGWindowID wid, CGWindowID parentWID, CGSAnimationRef *outAnimation);

/// Sets the progress of an animation.
CG_EXTERN CGError CGSSetWindowAnimationProgress(CGSAnimationRef animation, CGFloat progress);

/// DOCUMENTATION PENDING */
CG_EXTERN CGError CGSWindowAnimationChangeLevel(CGSAnimationRef animation, CGWindowLevel level);

/// DOCUMENTATION PENDING */
CG_EXTERN CGError CGSWindowAnimationSetParent(CGSAnimationRef animation, CGWindowID parent) AVAILABLE_MAC_OS_X_VERSION_10_5_AND_LATER;

/// Releases a window animation.
CG_EXTERN CGError CGSReleaseWindowAnimation(CGSAnimationRef animation);


#pragma mark - Window Accelleration


/// Gets the state of accelleration for the window.
CG_EXTERN CGError CGSWindowIsAccelerated(CGSConnectionID cid, CGWindowID wid, bool *outIsAccelerated);

/// Gets and sets if this window can be accellerated. I don't know if playing with this is safe.
CG_EXTERN CGError CGSWindowCanAccelerate(CGSConnectionID cid, CGWindowID wid, bool *outCanAccelerate);
CG_EXTERN CGError CGSWindowSetCanAccelerate(CGSConnectionID cid, CGWindowID wid, bool canAccelerate);


#pragma mark - Status Bar Windows


/// Registers or unregisters a window as a global status item (see `NSStatusItem`, `NSMenuExtra`).
/// Once a window is registered, the Window Server takes care of placing it in the apropriate location.
CG_EXTERN CGError CGSSystemStatusBarRegisterWindow(CGSConnectionID cid, CGWindowID wid, int priority);
CG_EXTERN CGError CGSUnregisterWindowWithSystemStatusBar(CGSConnectionID cid, CGWindowID wid);

/// Rearranges items in the system status bar. You should call this after registering or unregistering a status item or changing the window's width.
CG_EXTERN CGError CGSAdjustSystemStatusBarWindows(CGSConnectionID cid);


#pragma mark - Window Tags


/// Get the given tags for a window.  Pass kCGSRealMaximumTagSize to maxTagSize.
///
/// Tags are represented server-side as 64-bit integers, but CoreGraphics maintains compatibility
/// with 32-bit clients by requiring 2 32-bit options tags to be specified.  The first entry in the
/// options array populates the lower 32 bits, the last populates the upper 32 bits.
CG_EXTERN CGError CGSGetWindowTags(CGSConnectionID cid, CGWindowID wid, const CGSWindowTagBit tags[2], size_t maxTagSize);

/// Set the given tags for a window.  Pass kCGSRealMaximumTagSize to maxTagSize.
///
/// Tags are represented server-side as 64-bit integers, but CoreGraphics maintains compatibility
/// with 32-bit clients by requiring 2 32-bit options tags to be specified.  The first entry in the
/// options array populates the lower 32 bits, the last populates the upper 32 bits.
CG_EXTERN CGError CGSSetWindowTags(CGSConnectionID cid, CGWindowID wid, const CGSWindowTagBit tags[2], size_t maxTagSize);

/// Clear the given tags for a window.  Pass kCGSRealMaximumTagSize to maxTagSize. 
///
/// Tags are represented server-side as 64-bit integers, but CoreGraphics maintains compatibility
/// with 32-bit clients by requiring 2 32-bit options tags to be specified.  The first entry in the
/// options array populates the lower 32 bits, the last populates the upper 32 bits.
CG_EXTERN CGError CGSClearWindowTags(CGSConnectionID cid, CGWindowID wid, const CGSWindowTagBit tags[2], size_t maxTagSize);


#pragma mark - Window Backdrop


/// Creates a new window backdrop with a given material and frame.
///
/// the Window Server will apply the backdrop's material effect to the window using the
/// application's default connection.
CG_EXTERN CGSWindowBackdropRef CGSWindowBackdropCreateWithLevel(CGWindowID wid, CFStringRef materialName, CGWindowLevel level, CGRect frame) AVAILABLE_MAC_OS_X_VERSION_10_10_AND_LATER;

/// Releases a window backdrop object.
CG_EXTERN void CGSWindowBackdropRelease(CGSWindowBackdropRef backdrop) AVAILABLE_MAC_OS_X_VERSION_10_10_AND_LATER;

/// Activates the backdrop's effect.  OS X currently only makes the key window's backdrop active.
CG_EXTERN void CGSWindowBackdropActivate(CGSWindowBackdropRef backdrop) AVAILABLE_MAC_OS_X_VERSION_10_10_AND_LATER;
CG_EXTERN void CGSWindowBackdropDeactivate(CGSWindowBackdropRef backdrop) AVAILABLE_MAC_OS_X_VERSION_10_10_AND_LATER;

/// Sets the saturation of the backdrop.  For certain material types this can imitate the "vibrancy" effect in AppKit.
CG_EXTERN void CGSWindowBackdropSetSaturation(CGSWindowBackdropRef backdrop, CGFloat saturation) AVAILABLE_MAC_OS_X_VERSION_10_10_AND_LATER;

/// Sets the bleed for the window's backdrop effect.  Vibrant NSWindows use ~0.2.
CG_EXTERN void CGSWindowSetBackdropBackgroundBleed(CGWindowID wid, CGFloat bleedAmount) AVAILABLE_MAC_OS_X_VERSION_10_10_AND_LATER;

#endif /* CGS_WINDOW_INTERNAL_H */



---
File: /CGSWorkspace.h
---

/*
 * Copyright (C) 2007-2008 Alacatia Labs
 * 
 * This software is provided 'as-is', without any express or implied
 * warranty.  In no event will the authors be held liable for any damages
 * arising from the use of this software.
 * 
 * Permission is granted to anyone to use this software for any purpose,
 * including commercial applications, and to alter it and redistribute it
 * freely, subject to the following restrictions:
 * 
 * 1. The origin of this software must not be misrepresented; you must not
 *    claim that you wrote the original software. If you use this software
 *    in a product, an acknowledgment in the product documentation would be
 *    appreciated but is not required.
 * 2. Altered source versions must be plainly marked as such, and must not be
 *    misrepresented as being the original software.
 * 3. This notice may not be removed or altered from any source distribution.
 * 
 * Joe Ranieri joe@alacatia.com
 *
 */

//
//  Updated by Robert Widmann.
//  Copyright © 2015-2016 CodaFi. All rights reserved.
//  Released under the MIT license.
//

#ifndef CGS_WORKSPACE_INTERNAL_H
#define CGS_WORKSPACE_INTERNAL_H

#include "CGSConnection.h"
#include "CGSWindow.h"
#include "CGSTransitions.h"

typedef unsigned int CGSWorkspaceID;

/// The space ID given when we're switching spaces.
static const CGSWorkspaceID kCGSTransitioningWorkspaceID = 65538;

/// Gets and sets the current workspace.
CG_EXTERN CGError CGSGetWorkspace(CGSConnectionID cid, CGSWorkspaceID *outWorkspace);
CG_EXTERN CGError CGSSetWorkspace(CGSConnectionID cid, CGSWorkspaceID workspace);

/// Transitions to a workspace asynchronously. Note that `duration` is in seconds.
CG_EXTERN CGError CGSSetWorkspaceWithTransition(CGSConnectionID cid, CGSWorkspaceID workspace, CGSTransitionType transition, CGSTransitionFlags options, CGFloat duration);

/// Gets and sets the workspace for a window.
CG_EXTERN CGError CGSGetWindowWorkspace(CGSConnectionID cid, CGWindowID wid, CGSWorkspaceID *outWorkspace);
CG_EXTERN CGError CGSSetWindowWorkspace(CGSConnectionID cid, CGWindowID wid, CGSWorkspaceID workspace);

/// Gets the number of windows in the workspace.
CG_EXTERN CGError CGSGetWorkspaceWindowCount(CGSConnectionID cid, int workspaceNumber, int *outCount);
CG_EXTERN CGError CGSGetWorkspaceWindowList(CGSConnectionID cid, int workspaceNumber, int count, CGWindowID *list, int *outCount);

#endif

