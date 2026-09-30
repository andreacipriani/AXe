import Foundation
import Testing

@Suite("Settings first-tap E2E tests", .serialized, .enabled(if: isE2EEnabled))
struct SettingsTapTests {
    @Test("First selector tap from a fresh CLI process opens General", arguments: 1...5)
    func firstSelectorTapOpensGeneral(trial: Int) async throws {
        let udid = try TestHelpers.requireSimulatorUDID()
        _ = try await prepareSettings(udid: udid)

        try await TestHelpers.runAxeCommand(
            "tap --id com.apple.settings.general",
            simulatorUDID: udid
        )

        let opened = try await waitForElement("com.apple.settings.general.about", udid: udid, timeout: 3)
        #expect(opened != nil, "Trial \(trial): the first tap reported success but General did not open")
    }

    @Test("Alternative first taps open General", arguments: [
        "tap --label General --element-type Button",
        "tap --id com.apple.settings.general --tap-style physical"
    ])
    func alternativeFirstTapOpensGeneral(command: String) async throws {
        let udid = try TestHelpers.requireSimulatorUDID()
        _ = try await prepareSettings(udid: udid)

        try await TestHelpers.runAxeCommand(command, simulatorUDID: udid)

        let opened = try await waitForElement("com.apple.settings.general.about", udid: udid, timeout: 3)
        #expect(opened != nil, "The first tap reported success but General did not open")
    }

    @Test("First coordinate tap opens General")
    func firstCoordinateTapOpensGeneral() async throws {
        let udid = try TestHelpers.requireSimulatorUDID()
        let general = try await prepareSettings(udid: udid)
        let frame = try #require(general.frame)

        try await TestHelpers.runAxeCommand(
            "tap -x \(frame.x + frame.width / 2) -y \(frame.y + frame.height / 2)",
            simulatorUDID: udid
        )

        let opened = try await waitForElement("com.apple.settings.general.about", udid: udid, timeout: 3)
        #expect(opened != nil, "The first coordinate tap reported success but General did not open")
    }

    @Test("Batch first and subsequent taps share a prepared session")
    func batchTapsOpenAbout() async throws {
        let udid = try TestHelpers.requireSimulatorUDID()
        _ = try await prepareSettings(udid: udid)

        try await TestHelpers.runAxeCommand(
            "batch --ax-cache perStep --wait-timeout 3 --step \"tap --id com.apple.settings.general\" --step \"tap --id com.apple.settings.general.about\"",
            simulatorUDID: udid
        )

        let opened = try await waitForElement("ProductModelName", udid: udid, timeout: 3)
        #expect(opened != nil, "The batch reported success but About did not open")
    }

    private func prepareSettings(udid: String) async throws -> UIElement {
        _ = try await CommandRunner.run("xcrun simctl launch \(udid) com.apple.Preferences")
        try await Task.sleep(for: .seconds(1))

        for _ in 0..<3 {
            if let general = try await element("com.apple.settings.general", udid: udid) {
                return general
            }
            guard let back = try await element("BackButton", udid: udid) else { break }
            let frame = try #require(back.frame, "Settings back button has no frame")
            try await TestHelpers.runAxeCommand(
                "touch -x \(frame.x + frame.width / 2) -y \(frame.y + frame.height / 2) --down --up --delay 0.15",
                simulatorUDID: udid
            )
            try await Task.sleep(for: .milliseconds(300))
        }

        let general = try await waitForElement("com.apple.settings.general", udid: udid, timeout: 5)
        return try #require(general, "Settings did not return to its root page")
    }

    private func waitForElement(_ identifier: String, udid: String, timeout: TimeInterval) async throws -> UIElement? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let found = try await element(identifier, udid: udid) {
                return found
            }
            try await Task.sleep(for: .milliseconds(200))
        }
        return nil
    }

    private func element(_ identifier: String, udid: String) async throws -> UIElement? {
        let output = try await TestHelpers.runAxeCommand("describe-ui", simulatorUDID: udid)
        let roots = try UIStateParser.parseDescribeUIRoots(output.output)
        return UIStateParser.findElement(in: roots, withIdentifier: identifier)
    }
}
