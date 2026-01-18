import XCTest
@testable import LocumTrackerCore

final class RuralSubsidyServiceTests: XCTestCase {

    // MARK: - Eligibility Tests

    func testIsEligible_MMM1And2_ReturnsFalse() {
        XCTAssertFalse(RuralSubsidyService.isEligible(mmmClassification: 1))
        XCTAssertFalse(RuralSubsidyService.isEligible(mmmClassification: 2))
    }

    func testIsEligible_MMM3To7_ReturnsTrue() {
        for mmm in 3...7 {
            XCTAssertTrue(RuralSubsidyService.isEligible(mmmClassification: mmm))
        }
    }

    // MARK: - Session Validation Tests

    func testIsValidSession_Under3Hours_ReturnsFalse() {
        XCTAssertFalse(RuralSubsidyService.isValidSession(durationHours: 2.5))
        XCTAssertFalse(RuralSubsidyService.isValidSession(durationHours: 2.99))
    }

    func testIsValidSession_AtLeast3Hours_ReturnsTrue() {
        XCTAssertTrue(RuralSubsidyService.isValidSession(durationHours: 3.0))
        XCTAssertTrue(RuralSubsidyService.isValidSession(durationHours: 8.0))
    }

    func testValidSessionsForDay_CapsAt2() {
        XCTAssertEqual(RuralSubsidyService.validSessionsForDay(1), 1)
        XCTAssertEqual(RuralSubsidyService.validSessionsForDay(2), 2)
        XCTAssertEqual(RuralSubsidyService.validSessionsForDay(3), 2)
        XCTAssertEqual(RuralSubsidyService.validSessionsForDay(5), 2)
    }

    // MARK: - Quarter Session Tests

    func testCountedSessionsForQuarter_CapsAt104() {
        XCTAssertEqual(RuralSubsidyService.countedSessionsForQuarter(50), 50)
        XCTAssertEqual(RuralSubsidyService.countedSessionsForQuarter(104), 104)
        XCTAssertEqual(RuralSubsidyService.countedSessionsForQuarter(120), 104)
    }

    func testIsActiveQuarter_Under21_ReturnsFalse() {
        XCTAssertFalse(RuralSubsidyService.isActiveQuarter(sessions: 20))
        XCTAssertFalse(RuralSubsidyService.isActiveQuarter(sessions: 0))
    }

    func testIsActiveQuarter_AtLeast21_ReturnsTrue() {
        XCTAssertTrue(RuralSubsidyService.isActiveQuarter(sessions: 21))
        XCTAssertTrue(RuralSubsidyService.isActiveQuarter(sessions: 50))
    }

    // MARK: - Payment Matrix Tests

    func testGetAnnualPayment_Year1_VR_ReturnsCorrectAmounts() {
        let status = RegistrationStatus.vocationallyRegistered

        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 3, registrationStatus: status), 4_500)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 4, registrationStatus: status), 7_500)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 5, registrationStatus: status), 12_000)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 6, registrationStatus: status), 25_000)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 7, registrationStatus: status), 47_000)
    }

    func testGetAnnualPayment_Year4_VR_ReturnsCorrectAmounts() {
        let status = RegistrationStatus.vocationallyRegistered

        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 4, mmmClassification: 3, registrationStatus: status), 12_000)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 4, mmmClassification: 4, registrationStatus: status), 18_000)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 4, mmmClassification: 5, registrationStatus: status), 21_000)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 4, mmmClassification: 6, registrationStatus: status), 40_000)
        XCTAssertEqual(RuralSubsidyService.getAnnualPayment(yearLevel: 4, mmmClassification: 7, registrationStatus: status), 60_000)
    }

    func testGetAnnualPayment_NonVR_Returns80Percent() {
        let vrStatus = RegistrationStatus.vocationallyRegistered
        let nonVRStatus = RegistrationStatus.nonVocational

        let vrAmount = RuralSubsidyService.getAnnualPayment(yearLevel: 2, mmmClassification: 5, registrationStatus: vrStatus)
        let nonVRAmount = RuralSubsidyService.getAnnualPayment(yearLevel: 2, mmmClassification: 5, registrationStatus: nonVRStatus)

        XCTAssertEqual(nonVRAmount, vrAmount * 0.8, accuracy: 0.01)
    }

    func testGetAnnualPayment_OnApprovedTraining_ReturnsFullRate() {
        let trainingStatus = RegistrationStatus.onApprovedTraining
        let vrStatus = RegistrationStatus.vocationallyRegistered

        let trainingAmount = RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 6, registrationStatus: trainingStatus)
        let vrAmount = RuralSubsidyService.getAnnualPayment(yearLevel: 1, mmmClassification: 6, registrationStatus: vrStatus)

        XCTAssertEqual(trainingAmount, vrAmount)
    }

    func testGetAnnualPayment_YearLevelCapsAt4() {
        let status = RegistrationStatus.vocationallyRegistered

        let year4 = RuralSubsidyService.getAnnualPayment(yearLevel: 4, mmmClassification: 5, registrationStatus: status)
        let year5 = RuralSubsidyService.getAnnualPayment(yearLevel: 5, mmmClassification: 5, registrationStatus: status)
        let year10 = RuralSubsidyService.getAnnualPayment(yearLevel: 10, mmmClassification: 5, registrationStatus: status)

        XCTAssertEqual(year4, year5)
        XCTAssertEqual(year4, year10)
    }

    // MARK: - Year Level Calculation Tests

    func testCalculateYearLevel_NewParticipant_MMM35_StartsAtYear2() {
        let yearLevel = RuralSubsidyService.calculateYearLevel(
            paymentsReceived: 0,
            isNewParticipant: true,
            predominantMMM: 4
        )
        XCTAssertEqual(yearLevel, 2)
    }

    func testCalculateYearLevel_NewParticipant_MMM67_StartsAtYear1() {
        let yearLevel = RuralSubsidyService.calculateYearLevel(
            paymentsReceived: 0,
            isNewParticipant: true,
            predominantMMM: 7
        )
        XCTAssertEqual(yearLevel, 1)
    }

    func testCalculateYearLevel_ContinuingParticipant_ProgressesCorrectly() {
        XCTAssertEqual(RuralSubsidyService.calculateYearLevel(paymentsReceived: 0, isNewParticipant: false, predominantMMM: 5), 1)
        XCTAssertEqual(RuralSubsidyService.calculateYearLevel(paymentsReceived: 1, isNewParticipant: false, predominantMMM: 5), 2)
        XCTAssertEqual(RuralSubsidyService.calculateYearLevel(paymentsReceived: 2, isNewParticipant: false, predominantMMM: 5), 3)
        XCTAssertEqual(RuralSubsidyService.calculateYearLevel(paymentsReceived: 3, isNewParticipant: false, predominantMMM: 5), 4)
        XCTAssertEqual(RuralSubsidyService.calculateYearLevel(paymentsReceived: 10, isNewParticipant: false, predominantMMM: 5), 4)
    }

    // MARK: - Eligibility Check Tests

    func testCheckEligibility_NewParticipant_MMM35_Requires8In16() {
        let result = RuralSubsidyService.checkEligibility(
            activeQuartersInPeriod: 7,
            isNewParticipant: true,
            predominantMMM: 4
        )

        XCTAssertFalse(result.isEligible)
        XCTAssertEqual(result.requiredQuarters, 8)
        XCTAssertEqual(result.referencePeriodQuarters, 16)
        XCTAssertEqual(result.quartersNeeded, 1)
    }

    func testCheckEligibility_NewParticipant_MMM67_Requires4In8() {
        let result = RuralSubsidyService.checkEligibility(
            activeQuartersInPeriod: 4,
            isNewParticipant: true,
            predominantMMM: 7
        )

        XCTAssertTrue(result.isEligible)
        XCTAssertEqual(result.requiredQuarters, 4)
        XCTAssertEqual(result.referencePeriodQuarters, 8)
        XCTAssertEqual(result.quartersNeeded, 0)
    }

    func testCheckEligibility_ContinuingParticipant_Requires4In8() {
        let result = RuralSubsidyService.checkEligibility(
            activeQuartersInPeriod: 3,
            isNewParticipant: false,
            predominantMMM: 5
        )

        XCTAssertFalse(result.isEligible)
        XCTAssertEqual(result.requiredQuarters, 4)
        XCTAssertEqual(result.referencePeriodQuarters, 8)
        XCTAssertEqual(result.quartersNeeded, 1)
    }

    // MARK: - Session Validation Tests

    func testSessionValidation_ValidSession() {
        let result = SessionValidation.validate(durationHours: 4.0, mmmClassification: 5)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.validationErrors.isEmpty)
    }

    func testSessionValidation_TooShort_ReturnsError() {
        let result = SessionValidation.validate(durationHours: 2.5, mmmClassification: 5)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.validationErrors.count, 1)
        XCTAssertTrue(result.validationErrors[0].contains("3 hours"))
    }

    func testSessionValidation_InvalidMMM_ReturnsError() {
        let result = SessionValidation.validate(durationHours: 4.0, mmmClassification: 2)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.validationErrors.count, 1)
        XCTAssertTrue(result.validationErrors[0].contains("MMM 3-7"))
    }

    func testSessionValidation_MultipleErrors() {
        let result = SessionValidation.validate(durationHours: 2.0, mmmClassification: 1)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.validationErrors.count, 2)
    }

    // MARK: - Registration Status Tests

    func testRegistrationStatus_QualifiesForFullRate() {
        XCTAssertTrue(RegistrationStatus.vocationallyRegistered.qualifiesForFullRate)
        XCTAssertTrue(RegistrationStatus.onApprovedTraining.qualifiesForFullRate)
        XCTAssertFalse(RegistrationStatus.nonVocational.qualifiesForFullRate)
    }
}
