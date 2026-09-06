import XCTest
@testable import OutbreakEngine

final class SpreadRulesTests: XCTestCase {

    // MARK: Growth inside a territory

    func testGrowthNeedsCarriersAndHealthyPeople() {
        let blueprint = RegionCatalog.blueprint(.highbarrow)

        let empty = Fixture.region(.highbarrow, infectedFraction: 0)
        XCTAssertEqual(
            SpreadRules.newInfections(
                region: blueprint, state: empty, profile: Fixture.profile([]),
                difficulty: .tense, signature: .none
            ),
            0
        )

        let full = Fixture.region(.highbarrow, infectedFraction: 1.0)
        XCTAssertEqual(
            SpreadRules.newInfections(
                region: blueprint, state: full, profile: Fixture.profile([]),
                difficulty: .tense, signature: .none
            ),
            0
        )
    }

    func testGrowthNeverExceedsTheHealthyPopulation() {
        let blueprint = RegionCatalog.blueprint(.farhaven)
        for fraction in [0.001, 0.1, 0.5, 0.9, 0.999] {
            let state = Fixture.region(.farhaven, infectedFraction: fraction)
            let gained = SpreadRules.newInfections(
                region: blueprint, state: state,
                profile: Fixture.profile([.resonantCough, .denseBloom, .contactBloomI, .contactBloomII]),
                difficulty: .breezy, signature: .none
            )
            XCTAssertGreaterThanOrEqual(gained, 0)
            XCTAssertLessThanOrEqual(gained, state.healthy)
            XCTAssertFalse(gained.isNaN)
        }
    }

    func testGrowthCoefficientStaysBounded() {
        let everything = Fixture.profile(TraitID.allCases, strain: .nyx)
        for blueprint in RegionCatalog.all {
            for difficulty in Difficulty.allCases {
                let coefficient = SpreadRules.growthCoefficient(
                    region: blueprint,
                    state: Fixture.region(blueprint.id, infectedFraction: 0.5),
                    profile: everything, difficulty: difficulty, signature: .heatSeeking
                )
                XCTAssertGreaterThanOrEqual(coefficient, 0)
                XCTAssertLessThanOrEqual(coefficient, 2.0)
            }
        }
    }

    func testSuspendedTransportSlowsGrowthButDoesNotStopIt() {
        let blueprint = RegionCatalog.blueprint(.stillwater)
        let open = Fixture.region(.stillwater, infectedFraction: 0.2)
        let locked = Fixture.region(.stillwater, infectedFraction: 0.2, transportLocked: true)

        let openGrowth = SpreadRules.newInfections(
            region: blueprint, state: open, profile: Fixture.profile([]),
            difficulty: .tense, signature: .none
        )
        let lockedGrowth = SpreadRules.newInfections(
            region: blueprint, state: locked, profile: Fixture.profile([]),
            difficulty: .tense, signature: .none
        )
        XCTAssertLessThan(lockedGrowth, openGrowth)
        XCTAssertGreaterThan(lockedGrowth, 0)
    }

    func testClimateToleranceUnlocksHostileBands() {
        let frigid = RegionCatalog.blueprint(.coldspire)
        let state = Fixture.region(.coldspire, infectedFraction: 0.1)

        let bare = SpreadRules.growthCoefficient(
            region: frigid, state: state, profile: Fixture.profile([]),
            difficulty: .tense, signature: .none
        )
        let adapted = SpreadRules.growthCoefficient(
            region: frigid, state: state, profile: Fixture.profile([.cryoCoatI, .cryoCoatII]),
            difficulty: .tense, signature: .none
        )
        XCTAssertGreaterThan(adapted, bare)
    }

    func testStrainSignaturesPullTowardTheirBand() {
        XCTAssertGreaterThan(
            SpreadRules.signatureClimateMultiplier(.heatSeeking, climate: .tropical),
            SpreadRules.signatureClimateMultiplier(.heatSeeking, climate: .frigid)
        )
        XCTAssertGreaterThan(
            SpreadRules.signatureClimateMultiplier(.coldSeeking, climate: .frigid),
            SpreadRules.signatureClimateMultiplier(.coldSeeking, climate: .tropical)
        )
        for climate in Climate.allCases {
            XCTAssertEqual(SpreadRules.signatureClimateMultiplier(.none, climate: climate), 1.0)
            XCTAssertEqual(SpreadRules.signatureClimateMultiplier(.fadingTrail, climate: climate), 1.0)
        }
    }

    // MARK: Losses

    func testLossesRequireLethality() {
        let state = Fixture.region(.emberfall, infectedFraction: 0.4)
        XCTAssertEqual(SpreadRules.newLosses(state: state, profile: Fixture.profile([])), 0)

        let deadly = SpreadRules.newLosses(
            state: state, profile: Fixture.profile([.lethargy, .microTremor, .neuralBloom])
        )
        XCTAssertGreaterThan(deadly, 0)
        XCTAssertLessThanOrEqual(deadly, state.infected)
    }

    func testLossesNeverExceedCarriers() {
        var state = Fixture.region(.farhaven, infectedFraction: 1.0)
        state.infected = 10
        let profile = Fixture.profile([
            .lethargy, .microTremor, .neuralBloom, .chromaticFlush,
            .spectralFever, .systemicCascade, .totalCollapse
        ])
        XCTAssertLessThanOrEqual(SpreadRules.newLosses(state: state, profile: profile), 10)
    }

    // MARK: Travel between territories

    func testTravelNeedsAtLeastOneCarrier() {
        let empty = Fixture.region(.verdanmoor, infectedFraction: 0)
        for route in TravelRoute.allCases {
            XCTAssertEqual(
                SpreadRules.travelProbability(
                    route: route, source: empty, profile: Fixture.profile([]), scenario: .wildcard
                ),
                0
            )
        }
    }

    func testTravelRisesWithSaturationAndStaysBounded() {
        for route in TravelRoute.allCases {
            let low = Fixture.region(.verdanmoor, infectedFraction: 0.05)
            let high = Fixture.region(.verdanmoor, infectedFraction: 0.95)
            let lowProbability = SpreadRules.travelProbability(
                route: route, source: low, profile: Fixture.profile([]), scenario: .wildcard
            )
            let highProbability = SpreadRules.travelProbability(
                route: route, source: high, profile: Fixture.profile([]), scenario: .wildcard
            )
            XCTAssertLessThan(lowProbability, highProbability)
            XCTAssertLessThanOrEqual(highProbability, 0.85)
        }
    }

    func testTravelRespondsToTheMatchingTrait() {
        let source = Fixture.region(.verdanmoor, infectedFraction: 0.5)
        let air = Fixture.profile([.aerosolI, .aerosolII])

        let bareAir = SpreadRules.travelProbability(
            route: .air, source: source, profile: Fixture.profile([]), scenario: .wildcard
        )
        let boostedAir = SpreadRules.travelProbability(
            route: .air, source: source, profile: air, scenario: .wildcard
        )
        let unaffectedSea = SpreadRules.travelProbability(
            route: .sea, source: source, profile: air, scenario: .wildcard
        )
        let bareSea = SpreadRules.travelProbability(
            route: .sea, source: source, profile: Fixture.profile([]), scenario: .wildcard
        )

        XCTAssertGreaterThan(boostedAir, bareAir)
        XCTAssertEqual(unaffectedSea, bareSea, accuracy: 1e-12)
    }

    func testScenarioChangesTravelPressure() {
        let source = Fixture.region(.highbarrow, infectedFraction: 0.5)
        let island = SpreadRules.travelProbability(
            route: .air, source: source, profile: Fixture.profile([]), scenario: .isolatedIsland
        )
        let hub = SpreadRules.travelProbability(
            route: .air, source: source, profile: Fixture.profile([]), scenario: .transitHub
        )
        XCTAssertLessThan(island, hub)
    }

    func testOpenRoutesAreAlwaysUsable() {
        var generator = Fixture.generator()
        let source = Fixture.region(.verdanmoor, infectedFraction: 0.5)
        let destination = Fixture.region(.palewind)
        for route in TravelRoute.allCases {
            XCTAssertTrue(
                SpreadRules.routeIsOpen(
                    route: route, source: source, destination: destination,
                    profile: Fixture.profile([]), generator: &generator
                )
            )
        }
    }

    func testSuspendedRoutesBlockTheMatchingChannelOnly() {
        var generator = Fixture.generator()
        let source = Fixture.region(.verdanmoor, infectedFraction: 0.5, transportLocked: true)
        let destination = Fixture.region(.palewind)
        let profile = Fixture.profile([])

        XCTAssertFalse(
            SpreadRules.routeIsOpen(
                route: .air, source: source, destination: destination,
                profile: profile, generator: &generator
            )
        )
        XCTAssertFalse(
            SpreadRules.routeIsOpen(
                route: .sea, source: source, destination: destination,
                profile: profile, generator: &generator
            )
        )
        // Land is governed by border closure, not by transport suspension.
        XCTAssertTrue(
            SpreadRules.routeIsOpen(
                route: .land, source: source, destination: destination,
                profile: profile, generator: &generator
            )
        )
    }

    func testClosedBordersBlockLandBothWays() {
        var generator = Fixture.generator()
        let profile = Fixture.profile([])
        let closedSource = Fixture.region(.verdanmoor, infectedFraction: 0.5, bordersClosed: true)
        let closedDestination = Fixture.region(.palewind, bordersClosed: true)
        let openRegion = Fixture.region(.palewind)

        XCTAssertFalse(
            SpreadRules.routeIsOpen(
                route: .land, source: closedSource, destination: openRegion,
                profile: profile, generator: &generator
            )
        )
        XCTAssertFalse(
            SpreadRules.routeIsOpen(
                route: .land, source: Fixture.region(.verdanmoor, infectedFraction: 0.5),
                destination: closedDestination, profile: profile, generator: &generator
            )
        )
    }

    func testBorderSlipSometimesBeatsASuspendedRoute() {
        let source = Fixture.region(.verdanmoor, infectedFraction: 0.5, transportLocked: true)
        let destination = Fixture.region(.palewind)
        let profile = Fixture.profile([.cryoCoatI, .thermalShellI, .environmentalHardening, .borderSlip])

        var slipped = 0
        for seed in 0..<200 {
            var generator = SeededGenerator(seed: UInt64(seed + 1))
            if SpreadRules.routeIsOpen(
                route: .air, source: source, destination: destination,
                profile: profile, generator: &generator
            ) {
                slipped += 1
            }
        }
        XCTAssertGreaterThan(slipped, 0)
        XCTAssertLessThan(slipped, 200)
    }

    func testSeedCountIsAlwaysAtLeastOnePerson() {
        for blueprint in RegionCatalog.all {
            let seed = SpreadRules.seedCount(for: blueprint.population)
            XCTAssertGreaterThanOrEqual(seed, 1)
            XCTAssertLessThan(seed, Double(blueprint.population))
        }
        XCTAssertEqual(SpreadRules.seedCount(for: 0), 1)
    }
}
