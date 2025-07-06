# Annotation Coordinate Fix - Test Cases

## Overview

This document describes the test cases created to verify the coordinate transformation bug fix in Peekaboo's annotation feature. The bug caused UI element overlay boxes to be misaligned with the actual controls when drawing annotated screenshots.

## The Bug

**Problem**: UI elements are captured with screen coordinates (absolute position on screen), but when drawing annotations on the screenshot image, these coordinates were not being transformed to window-relative coordinates. This caused overlay boxes to appear at the wrong positions when the window was not at the screen origin (0,0).

**Root Cause**: 
1. UI elements from the Accessibility API use screen coordinates
2. The screenshot image represents only the window content
3. Drawing annotations requires window-relative coordinates
4. The transformation from screen to window coordinates was missing

**Fix**: 
1. Added `windowBounds: CGRect?` to `CaptureResult` and `SessionData` structures
2. Pass window bounds through the capture and annotation pipeline
3. Transform element coordinates from screen space to window space before drawing:
   ```swift
   elementFrame.origin.x -= windowBounds.origin.x
   elementFrame.origin.y -= windowBounds.origin.y
   ```

## Test Categories

### 1. Data Structure Tests

#### Window Bounds Storage (`testWindowBoundsStorage`)
- Verifies that window bounds are properly stored in session data
- Ensures the bounds persist through save/load cycle
- Critical for maintaining coordinate context

#### Capture Result Window Bounds (`testWindowBoundsStorage` in unit tests)
- Verifies `CaptureResult` properly stores window bounds
- Tests all three capture modes: screen, window, frontmost

### 2. Coordinate Transformation Tests

#### Window at Origin (`testCoordinateTransformationWindowAtOrigin`)
- Tests the simple case where window is at (0,0)
- Verifies that screen coordinates match window coordinates
- Tests Y-axis flip for NSGraphicsContext

#### Offset Window (`testCoordinateTransformationOffsetWindow`)
- **This is the core bug test case**
- Window at position (300, 400) with element at (450, 500)
- Verifies transformation: element should be at (150, 100) relative to window
- Tests Y-axis flip after transformation

#### Multiple Elements (`testMultipleElementsRelativeSpacing`)
- Tests that relative spacing between elements is preserved
- Three buttons in a row maintain their 90px spacing after transformation
- Verifies all elements at same Y coordinate stay aligned

### 3. Edge Case Tests

#### Element at Window Corner (`testElementAtWindowCorner`)
- Element exactly at window's top-left corner
- Should transform to (0, 0) in window coordinates
- Tests boundary condition

#### Partially Visible Element (`testPartiallyVisibleElement`)
- Element that extends beyond window bounds
- Verifies coordinates are still transformed correctly
- Important for elements near window edges

#### Nil Window Bounds (`testNilWindowBoundsFallback`)
- Tests full-screen capture scenario where windowBounds is nil
- Coordinates should not be transformed
- Elements maintain screen coordinates

### 4. Drawing Tests

#### Label Positioning (`testLabelPositioningAfterTransform`)
- Verifies element ID labels are positioned correctly after transformation
- Labels should be relative to transformed element position
- Tests padding and offset calculations

#### Y-Axis Flip (`testYAxisFlipTransformation`)
- NSGraphicsContext has origin at bottom-left
- Screen coordinates have origin at top-left
- Tests the flip calculation: `imageHeight - y - elementHeight`

### 5. Regression Tests

#### TextEdit Toolbar Buttons (`testTextEditToolbarButtonsAlignment`)
- Specific test for the TextEdit case that revealed the bug
- Uses approximate real-world values from TextEdit window
- Verifies buttons stay within window bounds after transformation
- Confirms relative spacing is preserved

## Test Execution

### Unit Tests
Run the coordinate transformation tests:
```bash
cd peekaboo-cli
swift test --filter AnnotatedScreenshotTests
```

### Integration Tests
Run with actual window capture (requires permissions):
```bash
RUN_LOCAL_TESTS=true swift test --filter AnnotationIntegrationTests
```

## Test Results

All 14 unit tests pass, verifying:
- ✅ Window bounds are properly stored and retrieved
- ✅ Coordinate transformation math is correct
- ✅ Edge cases are handled properly
- ✅ Multiple elements maintain relative positions
- ✅ Labels are positioned correctly
- ✅ The specific TextEdit bug is fixed

## Manual Verification

The fix was manually verified by:
1. Running TextEdit automation with `./peekaboo see --app TextEdit --annotate`
2. Confirming overlay boxes align with actual UI controls
3. Testing with windows at various screen positions
4. Verifying font dropdowns, buttons, and text fields are properly annotated

## Conclusion

The comprehensive test suite ensures the coordinate transformation bug is fixed and prevents regression. The tests cover the mathematical transformation, edge cases, and real-world scenarios like the TextEdit toolbar that originally revealed the issue.