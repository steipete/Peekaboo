import CoreGraphics
import Darwin
import PeekabooFoundation
import Testing
@testable import PeekabooAutomationKit

@MainActor
struct HotkeyServiceTargetingTests {
    @Test func `targeted hotkey planner accepts one primary key with modifiers`() throws {
        let service = HotkeyService()

        let plan = try service.targetedHotkeyPlanForTesting(["command", "shift", "p"])

        #expect(plan.primaryKey == "p")
        #expect(plan.keyCode == 0x23)
        #expect(plan.flags.contains(.maskCommand))
        #expect(plan.flags.contains(.maskShift))
    }

    @Test func `targeted hotkey planner rejects modifier-only input`() throws {
        let service = HotkeyService()

        #expect(throws: PeekabooError.self) {
            _ = try service.targetedHotkeyPlanForTesting(["cmd", "shift"])
        }
    }

    @Test func `targeted hotkey planner rejects multiple primary keys`() throws {
        let service = HotkeyService()

        #expect(throws: PeekabooError.self) {
            _ = try service.targetedHotkeyPlanForTesting(["cmd", "k", "c"])
        }
    }

    @Test func `targeted hotkey planner accepts foreground modifier aliases`() throws {
        let service = HotkeyService()

        let plan = try service.targetedHotkeyPlanForTesting(["function", "f1"])

        #expect(plan.primaryKey == "f1")
        #expect(plan.keyCode == 0x7A)
        #expect(plan.flags.contains(.maskSecondaryFn))
    }

    @Test func `targeted hotkey planner accepts AXorcist key aliases`() throws {
        let service = HotkeyService()

        let targetedPlan = try service.targetedHotkeyPlanForTesting(["cmd", "arrow_up"])

        #expect(targetedPlan.primaryKey == "up")
        #expect(targetedPlan.keyCode == 0x7E)
        #expect(targetedPlan.flags.contains(.maskCommand))
    }

    @Test func `targeted hotkey planner accepts documented punctuation key names`() throws {
        let service = HotkeyService()

        let commaPlan = try service.targetedHotkeyPlanForTesting(["cmd", "comma"])
        let slashPlan = try service.targetedHotkeyPlanForTesting(["cmd", "slash"])

        #expect(commaPlan.primaryKey == "comma")
        #expect(commaPlan.keyCode == 0x2B)
        #expect(slashPlan.primaryKey == "slash")
        #expect(slashPlan.keyCode == 0x2C)
    }

    @Test func `targeted hotkey planner normalizes foreground key aliases`() throws {
        let service = HotkeyService()

        let returnPlan = try service.targetedHotkeyPlanForTesting(["enter"])
        let deletePlan = try service.targetedHotkeyPlanForTesting(["backspace"])
        let delPlan = try service.targetedHotkeyPlanForTesting(["del"])

        #expect(returnPlan.primaryKey == "return")
        #expect(returnPlan.keyCode == 0x24)
        #expect(deletePlan.primaryKey == "delete")
        #expect(deletePlan.keyCode == 0x33)
        #expect(delPlan.primaryKey == "delete")
        #expect(delPlan.keyCode == 0x33)
    }

    @Test func `foreground hotkey parser trims and normalizes aliases before AXorcist delivery`() throws {
        let service = HotkeyService()

        let keys = try service.parsedKeysForTesting(" meta, SPACEBAR , backspace, cmdOrCtrl, del ")

        #expect(keys == ["cmd", "space", "delete", "cmd", "delete"])
    }

    @Test func `hold duration conversion rejects overflow before posting events`() throws {
        #expect(throws: PeekabooError.self) {
            _ = try HotkeyService.holdNanosecondsForTesting(Int.max)
        }
    }

    @Test func `targeted hotkey reports event synthesizing permission failures`() async throws {
        let service = HotkeyService(postEventAccessEvaluator: { false })

        do {
            try await service.hotkey(
                keys: "cmd,l",
                holdDuration: 50,
                targetProcessIdentifier: getpid())
            Issue.record("Expected event-synthesizing permission error")
        } catch PeekabooError.permissionDeniedEventSynthesizing {
            // Expected.
        } catch {
            Issue.record("Expected event-synthesizing permission error, got \(error)")
        }
    }

    @Test func `targeted hotkey posts key down and key up to target process`() async throws {
        var postedEvents: [(type: CGEventType, keyCode: Int64, flags: CGEventFlags, pid: pid_t)] = []
        let service = HotkeyService(
            postEventAccessEvaluator: { true },
            eventPoster: { event, pid in
                postedEvents.append((
                    type: event.type,
                    keyCode: event.getIntegerValueField(.keyboardEventKeycode),
                    flags: event.flags,
                    pid: pid))
            })

        try await service.hotkey(keys: "cmd,shift,l", holdDuration: 0, targetProcessIdentifier: getpid())

        #expect(postedEvents.count == 2)
        #expect(postedEvents.map(\.type) == [.keyDown, .keyUp])
        #expect(postedEvents.map(\.keyCode) == [0x25, 0x25])
        #expect(postedEvents.allSatisfy { $0.flags.contains(.maskCommand) && $0.flags.contains(.maskShift) })
        #expect(postedEvents.allSatisfy { $0.pid == getpid() })
    }

    @Test func `process liveness check rejects stale pids`() {
        #expect(HotkeyService.isProcessAliveForTesting(getpid()))
        #expect(!HotkeyService.isProcessAliveForTesting(pid_t(Int32.max)))
    }
}
