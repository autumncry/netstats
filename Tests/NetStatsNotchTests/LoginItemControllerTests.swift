import ServiceManagement
import XCTest
@testable import NetStatsCore

final class LoginItemControllerTests: XCTestCase {
    @MainActor
    func testOpeningSettingsReadsSystemStateWithoutChangingLoginItems() {
        for status in [SMAppService.Status.notRegistered, .enabled, .requiresApproval, .notFound] {
            let service = TestLoginItemService(status: status)
            let controller = LoginItemController(service: service)
            XCTAssertEqual(controller.status, status)
            XCTAssertEqual(service.registerCalls, 0)
            XCTAssertEqual(service.unregisterCalls, 0)
        }
    }

    @MainActor
    func testEnablingReportsApprovalNeededInsteadOfClaimingItIsEnabled() async {
        let service = TestLoginItemService(status: .notRegistered)
        service.registrationResult = .requiresApproval
        let controller = LoginItemController(service: service)
        await controller.setEnabled(true)
        XCTAssertEqual(controller.status, .requiresApproval)
        XCTAssertTrue(controller.isRegistered)
        XCTAssertFalse(controller.isUpdating)
        XCTAssertNil(controller.errorMessage)
    }

    @MainActor
    func testFailedRegistrationKeepsActualDisabledStateAndExplainsFailure() async {
        let service = TestLoginItemService(status: .notRegistered)
        service.registrationError = NSError(domain: "LoginItemTest", code: 1,
                                            userInfo: [NSLocalizedDescriptionKey: "Registration denied"])
        let controller = LoginItemController(service: service)
        await controller.setEnabled(true)
        XCTAssertEqual(controller.status, .notRegistered)
        XCTAssertFalse(controller.isRegistered)
        XCTAssertEqual(controller.errorMessage, "Registration denied")
        XCTAssertFalse(controller.isUpdating)
    }

    @MainActor
    func testDisablingCanCancelPendingApproval() async {
        let service = TestLoginItemService(status: .requiresApproval)
        let controller = LoginItemController(service: service)
        await controller.setEnabled(false)
        XCTAssertEqual(controller.status, .notRegistered)
        XCTAssertFalse(controller.isRegistered)
        XCTAssertEqual(service.unregisterCalls, 1)
    }

    @MainActor
    func testFailedUnregisterKeepsActualEnabledState() async {
        let service = TestLoginItemService(status: .enabled)
        service.unregistrationError = NSError(domain: "LoginItemTest", code: 2,
                                              userInfo: [NSLocalizedDescriptionKey: "Cannot unregister"])
        let controller = LoginItemController(service: service)
        await controller.setEnabled(false)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertTrue(controller.isRegistered)
        XCTAssertEqual(controller.errorMessage, "Cannot unregister")
    }

    @MainActor
    func testRefreshAndToggleReconcileChangesMadeInSystemSettings() async {
        let service = TestLoginItemService(status: .enabled)
        let controller = LoginItemController(service: service)
        service.status = .requiresApproval
        controller.refresh()
        XCTAssertEqual(controller.status, .requiresApproval)
        service.status = .notRegistered
        await controller.setEnabled(true)
        XCTAssertEqual(controller.status, .enabled)
        XCTAssertEqual(service.registerCalls, 1)
    }

    @MainActor
    func testEnablingAlreadyRegisteredItemDoesNotRegisterAgain() async {
        for status in [SMAppService.Status.enabled, .requiresApproval] {
            let service = TestLoginItemService(status: status)
            let controller = LoginItemController(service: service)
            await controller.setEnabled(true)
            XCTAssertEqual(service.registerCalls, 0)
            XCTAssertEqual(controller.status, status)
        }
    }
}

@MainActor
private final class TestLoginItemService: LoginItemService {
    var status: SMAppService.Status
    var registrationResult: SMAppService.Status = .enabled
    var registrationError: Error?
    var unregistrationError: Error?
    private(set) var registerCalls = 0
    private(set) var unregisterCalls = 0

    init(status: SMAppService.Status) { self.status = status }

    func register() throws {
        registerCalls += 1
        if let registrationError { throw registrationError }
        status = registrationResult
    }

    func unregister() async throws {
        unregisterCalls += 1
        if let unregistrationError { throw unregistrationError }
        status = .notRegistered
    }

    func openSystemSettings() {}
}
