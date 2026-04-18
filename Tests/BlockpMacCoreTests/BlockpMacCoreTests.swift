import Foundation
@testable import BlockpMacCore

// Unit tests for BlockpMacCore
// Note: Tests can be run using swift test or integrated into CI/CD
// Current implementation uses the self-test in main.swift as the primary test harness

final class BlockpMacCoreTests {
    private var tempStatePath: String!
    private var manager: CoreManager!

    func setUp() throws {
        let tempDir = NSTemporaryDirectory() + UUID().uuidString + "/"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        tempStatePath = tempDir + "state.json"
        manager = CoreManager(store: StateStore(stateFilePath: tempStatePath))
    }

    func tearDown() throws {
        let dir = tempStatePath.replacingOccurrences(of: "/state.json", with: "")
        try? FileManager.default.removeItem(atPath: dir)
    }

    func testStrictModeOnlyBlocksWhenEnabled() throws {
        try setUp()
        defer { try? tearDown() }

        let rules = [BlockRule(type: .domain, value: "test.com")]
        _ = try manager.replaceRules(rules)

        // Start session with strict mode disabled
        var policy = try manager.getState().policy
        policy.strictMode = false
        _ = try manager.setPolicy(policy)
        _ = try manager.startSession(durationSeconds: 60)

        // Should be able to stop session without penalty
        let state1 = try manager.stopSession()
        assert(!state1.session.isActive, "Session should be inactive after stop")

        // Start again, enable strict mode
        policy.strictMode = true
        _ = try manager.setPolicy(policy)
        _ = try manager.startSession(durationSeconds: 60, now: Date().addingTimeInterval(120))

        // Now should not be able to stop early with strict mode
        do {
            _ = try manager.stopSession(now: Date().addingTimeInterval(120))
            assert(false, "Should have thrown strictSessionCannotStop error")
        } catch CoreManagerError.strictSessionCannotStop {
            // Expected
        }
        print("✓ testStrictModeOnlyBlocksWhenEnabled")
    }

    func testCanStopSessionLogic() throws {
        try setUp()
        defer { try? tearDown() }

        let state = try manager.getState()
        assert(state.session.endsAt == nil || !state.session.isActive)

        _ = try manager.startSession(durationSeconds: 60)
        let sessionState = try manager.getState()
        assert(sessionState.session.isActive)

        // Can stop after time expires
        let futureDate = Date().addingTimeInterval(61)
        let finalState = try manager.stopSession(now: futureDate)
        assert(!finalState.session.isActive)
        print("✓ testCanStopSessionLogic")
    }

    func testAllowlistModeBlocking() throws {
        try setUp()
        defer { try? tearDown() }

        let rules = [BlockRule(type: .domain, value: "approved.com")]
        _ = try manager.replaceRules(rules)

        // Set allowlist mode
        let policy = FocusPolicy(
            strictMode: false,
            enforcementMode: .allowlist
        )
        _ = try manager.setPolicy(policy)
        _ = try manager.startSession(durationSeconds: 60)

        // Approved domain should not be blocked
        let allowedDecision = try manager.evaluate(host: "www.approved.com")
        assert(!allowedDecision.shouldBlock)
        assert(allowedDecision.reason == .activeSessionAllowlistRuleMatch)

        // Non-approved domain should be blocked
        let blockedDecision = try manager.evaluate(host: "example.com")
        assert(blockedDecision.shouldBlock)
        assert(blockedDecision.reason == .activeSessionAllowlistRuleMiss)
        print("✓ testAllowlistModeBlocking")
    }

    func testBlocklistModeBlocking() throws {
        try setUp()
        defer { try? tearDown() }

        let rules = [BlockRule(type: .domain, value: "blocked.com")]
        _ = try manager.replaceRules(rules)

        let policy = FocusPolicy(
            strictMode: false,
            enforcementMode: .blocklist
        )
        _ = try manager.setPolicy(policy)
        _ = try manager.startSession(durationSeconds: 60)

        // Blocked domain should be blocked
        let blockedDecision = try manager.evaluate(host: "www.blocked.com")
        assert(blockedDecision.shouldBlock)

        // Non-blocked domain should be allowed
        let allowedDecision = try manager.evaluate(host: "example.com")
        assert(!allowedDecision.shouldBlock)
        print("✓ testBlocklistModeBlocking")
    }

    func testRuleManagement() throws {
        try setUp()
        defer { try? tearDown() }

        let rule1 = BlockRule(type: .domain, value: "test1.com")
        let rule2 = BlockRule(type: .exactHost, value: "exact.test2.com")
        let rule3 = BlockRule(type: .keyword, value: "casino")

        var state = try manager.addRule(rule1)
        assert(state.rules.contains(rule1))

        state = try manager.addRule(rule2)
        assert(state.rules.count == 2)

        state = try manager.addRule(rule3)
        assert(state.rules.count == 3)

        state = try manager.removeRule(rule2)
        assert(!state.rules.contains(rule2))
        assert(state.rules.count == 2)

        let newRules = [BlockRule(type: .domain, value: "newtest.com")]
        state = try manager.replaceRules(newRules)
        assert(state.rules.count == 1)
        assert(state.rules.contains(newRules[0]))
        print("✓ testRuleManagement")
    }

    // MARK: - Test Runner
    static func runAll() throws {
        let tests = BlockpMacCoreTests()
        try tests.testStrictModeOnlyBlocksWhenEnabled()
        try tests.testCanStopSessionLogic()
        try tests.testAllowlistModeBlocking()
        try tests.testBlocklistModeBlocking()
        try tests.testRuleManagement()
        print("\nAll unit tests passed!")
    }
}
