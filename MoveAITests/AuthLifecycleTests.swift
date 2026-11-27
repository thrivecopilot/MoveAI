//
//  AuthLifecycleTests.swift
//  MoveAITests
//
//  Sign in with Apple lifecycle: keychain persistence, sign-out cleanup, and
//  the account-deletion data wipe.
//

import Security
import XCTest
@testable import MoveAI

@MainActor
final class AuthLifecycleTests: XCTestCase {

    private var documents: URL!
    private var createdFiles: [URL] = []

    override func setUp() async throws {
        documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.removeItem(at: documents.appendingPathComponent("Sessions", isDirectory: true))
        UserDefaults.standard.set(true, forKey: "sessions_migrated_to_files")
        // Ensure no auth state leaks between tests.
        AppleAuthManager().signOut()
    }

    override func tearDown() async throws {
        AppleAuthManager().signOut()
        try? FileManager.default.removeItem(at: documents.appendingPathComponent("Sessions", isDirectory: true))
        for url in createdFiles {
            try? FileManager.default.removeItem(at: url)
        }
        createdFiles = []
    }

    private func makeVideoFile(named name: String) throws -> URL {
        let url = documents.appendingPathComponent(name)
        try Data("fake video".utf8).write(to: url)
        createdFiles.append(url)
        return url
    }

    /// Unsigned simulator builds (the CI workflow builds with
    /// `CODE_SIGNING_ALLOWED=NO`) have no keychain entitlement, so every SecItem
    /// call fails with errSecMissingEntitlement (-34018). Skip rather than fail
    /// there; signed builds (Xcode's default) still run the keychain tests.
    private func skipIfKeychainUnavailable() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "auth_test_keychain_probe"
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data("probe".utf8)
        let status = SecItemAdd(add as CFDictionary, nil)
        SecItemDelete(query as CFDictionary)
        if status == errSecMissingEntitlement {
            throw XCTSkip("Keychain unavailable in an unsigned build (errSecMissingEntitlement)")
        }
    }

    // MARK: - Keychain round trip

    func testKeychainSaveLoadDelete() throws {
        try skipIfKeychainUnavailable()
        let keychain = KeychainHelper()
        keychain.save("test-value", forKey: "auth_test_key")
        XCTAssertEqual(keychain.load(forKey: "auth_test_key"), "test-value")

        keychain.delete(forKey: "auth_test_key")
        XCTAssertNil(keychain.load(forKey: "auth_test_key"))
    }

    // MARK: - Sign in / sign out persistence

    func testStoredUserSurvivesNewManagerInstance() throws {
        try skipIfKeychainUnavailable()
        let manager = AppleAuthManager()
        manager.saveUserData(userIdentifier: "user-123", email: "a@b.com", fullName: nil)
        XCTAssertTrue(manager.isSignedIn)

        let reloaded = AppleAuthManager()
        XCTAssertTrue(reloaded.isSignedIn, "Stored credential must survive relaunch")
        XCTAssertEqual(reloaded.currentUser?.identifier, "user-123")
    }

    func testSignOutClearsStoredCredential() {
        let manager = AppleAuthManager()
        manager.saveUserData(userIdentifier: "user-123", email: "a@b.com", fullName: nil)

        manager.signOut()
        XCTAssertFalse(manager.isSignedIn)
        XCTAssertNil(manager.currentUser)

        let reloaded = AppleAuthManager()
        XCTAssertFalse(reloaded.isSignedIn, "Sign-out must clear the keychain, not just memory")
    }

    func testValidateCredentialStateNoOpsWithoutStoredCredential() async {
        // UI-test sessions set the onboarding flag without a real credential;
        // validation must not touch state in that case.
        let manager = AppleAuthManager()
        XCTAssertFalse(manager.isSignedIn)
        await manager.validateCredentialState()
        XCTAssertFalse(manager.isSignedIn)
    }

    // MARK: - Account deletion wipe

    func testDeleteAllDataRemovesSessionsAndOwnedVideos() throws {
        let videoA = try makeVideoFile(named: "wipe_a.mov")
        let videoB = try makeVideoFile(named: "wipe_b.mov")
        let manager = SessionManager()
        manager.addSession(Session(movementType: .squat, videoURL: videoA))
        manager.addSession(Session(movementType: .running, videoURL: videoB))
        XCTAssertEqual(manager.sessions.count, 2)

        manager.deleteAllData()

        XCTAssertTrue(manager.sessions.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: videoA.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: videoB.path))

        let reloaded = SessionManager()
        XCTAssertTrue(reloaded.sessions.isEmpty, "Wipe must persist across relaunch")
    }
}
