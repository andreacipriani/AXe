import Foundation
import Testing

@Suite("Settings first-tap E2E tests", .serialized, .enabled(if: isE2EEnabled))
struct SettingsTapTests {
    @Test("First selector tap from a fresh CLI process opens General", arguments: 1...5)
    func firstSelectorTapOpensGeneral(trial: Int) async throws {
        let udid = try TestHelpers.requireSimulatorUDID()
        _ = try await CommandRunner.run("xcrun simctl launch \(udid) com.apple.Preferences")
        try await Task.sleep(for: .seconds(1))
        try await resetToSettingsRoot(udid: udid)

        try await TestHelpers.runAxeCommand(
            "tap --id com.apple.settings.general",
            simulatorUDID: udid
        )

        let opened = try await waitForElement("BackButton", udid: udid, timeout: 3)
        #expect(opened, "Trial \(trial): the first tap reported success but General did not open")
    }

    private func resetToSettingsRoot(udid: String) async throws {
        if (try? await hasElement("BackButton", udid: udid)) == true {
            try await TestHelpers.runAxeCommand(
                "touch -x 38 -y 84 --down --up --delay 0.15",
                simulatorUDID: udid
            )
        }
        let ready = try await waitForElement("com.apple.settings.general", udid: udid, timeout: 5)
        try #require(ready, "Settings did not return to its root page")
    }

    private func waitForElement(_ identifier: String, udid: String, timeout: TimeInterval) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? await hasElement(identifier, udid: udid)) == true {
                return true
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        return false
    }

    private func hasElement(_ identifier: String, udid: String) async throws -> Bool {
        let output = try await TestHelpers.runAxeCommand("describe-ui", simulatorUDID: udid)
        let roots = try UIStateParser.parseDescribeUIRoots(output.output)
        return roots.contains { root in
            UIStateParser.findElement(in: root, withIdentifier: identifier) != nil
        }
    }
}
