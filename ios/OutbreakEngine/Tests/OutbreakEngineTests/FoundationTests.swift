import XCTest
@testable import OutbreakEngine

/// Determinism and catalog integrity — the two things every other test relies on.
final class SeededGeneratorTests: XCTestCase {

    func testSameSeedProducesSameSequence() {
        var a = SeededGenerator(seed: 12345)
        var b = SeededGenerator(seed: 12345)
        for _ in 0..<200 {
            XCTAssertEqual(a.next(), b.next())
        }
    }

    func testDifferentSeedsDiverge() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        let first = (0..<50).map { _ in a.next() }
        let second = (0..<50).map { _ in b.next() }
        XCTAssertNotEqual(first, second)
    }

    func testZeroSeedIsNotDegenerate() {
        var generator = SeededGenerator(seed: 0)
        let values = Set((0..<50).map { _ in generator.next() })
        XCTAssertEqual(values.count, 50, "A zero seed must not collapse the stream")
    }

    func testUnitStaysInRange() {
        var generator = SeededGenerator(seed: 99)
        for _ in 0..<2000 {
            let value = generator.unit()
            XCTAssertGreaterThanOrEqual(value, 0)
            XCTAssertLessThan(value, 1)
        }
    }

    func testChanceClampsOutOfRangeProbabilities() {
        var generator = SeededGenerator(seed: 5)
        XCTAssertFalse(generator.chance(0))
        XCTAssertFalse(generator.chance(-3))
        XCTAssertTrue(generator.chance(1))
        XCTAssertTrue(generator.chance(4))
    }

    func testChanceIsRoughlyCalibrated() {
        var generator = SeededGenerator(seed: 2024)
        let hits = (0..<20_000).reduce(0) { total, _ in
            total + (generator.chance(0.25) ? 1 : 0)
        }
        let rate = Double(hits) / 20_000
        XCTAssertEqual(rate, 0.25, accuracy: 0.02)
    }

    func testIntStaysInRangeIncludingSingleValueRange() {
        var generator = SeededGenerator(seed: 77)
        for _ in 0..<500 {
            let value = generator.int(in: 3...7)
            XCTAssertGreaterThanOrEqual(value, 3)
            XCTAssertLessThanOrEqual(value, 7)
        }
        XCTAssertEqual(generator.int(in: 9...9), 9)
    }

    func testPickReturnsNilForEmptyCollection() {
        var generator = SeededGenerator(seed: 1)
        let empty: [Int] = []
        XCTAssertNil(generator.pick(empty))
    }

    func testStringSeedIsStableAcrossProcesses() {
        // Hard-coded because the daily challenge depends on this exact value
        // being identical on every device and every launch.
        XCTAssertEqual(SeededGenerator.seed(from: ""), 0xCBF29CE484222325)
        XCTAssertEqual(
            SeededGenerator.seed(from: "outbreak-daily-2026-01-01"),
            SeededGenerator.seed(from: "outbreak-daily-2026-01-01")
        )
        XCTAssertNotEqual(
            SeededGenerator.seed(from: "2026-01-01"),
            SeededGenerator.seed(from: "2026-01-02")
        )
    }
}

final class RegionCatalogTests: XCTestCase {

    func testEveryRegionHasABlueprint() {
        for id in RegionID.allCases {
            XCTAssertEqual(RegionCatalog.blueprint(id).id, id)
        }
        XCTAssertEqual(RegionCatalog.all.count, RegionID.allCases.count)
    }

    func testNeighboursAreSymmetricAndNeverSelfReferential() {
        for blueprint in RegionCatalog.all {
            XCTAssertFalse(
                blueprint.neighbors.contains(blueprint.id),
                "\(blueprint.id.rawValue) borders itself"
            )
            for neighbor in blueprint.neighbors {
                XCTAssertTrue(
                    RegionCatalog.blueprint(neighbor).neighbors.contains(blueprint.id),
                    "\(neighbor.rawValue) is missing the return link to \(blueprint.id.rawValue)"
                )
            }
            XCTAssertEqual(
                Set(blueprint.neighbors).count, blueprint.neighbors.count,
                "\(blueprint.id.rawValue) lists a duplicate neighbour"
            )
        }
    }

    func testBoardIsConnectedForAtLeastOneRoute() {
        // Every territory must be reachable, or a run could never be won.
        // Farhaven has no land links, so air or sea has to cover it.
        for blueprint in RegionCatalog.all where blueprint.neighbors.isEmpty {
            XCTAssertTrue(
                blueprint.hasAirport || blueprint.hasSeaport,
                "\(blueprint.id.rawValue) is unreachable by any route"
            )
        }
    }

    func testPopulationsArePositiveAndSumToWorld() {
        for blueprint in RegionCatalog.all {
            XCTAssertGreaterThan(blueprint.population, 0)
        }
        let sum = RegionCatalog.all.reduce(0) { $0 + $1.population }
        XCTAssertEqual(RegionCatalog.worldPopulation, sum)
        XCTAssertGreaterThan(RegionCatalog.worldPopulation, 0)
    }

    func testMapGeometryIsNormalised() {
        for blueprint in RegionCatalog.all {
            XCTAssertGreaterThanOrEqual(blueprint.mapShape.count, 3)
            for point in blueprint.mapShape + [blueprint.mapCenter] {
                XCTAssertTrue((0...1).contains(point.x), "\(blueprint.id.rawValue) x out of range")
                XCTAssertTrue((0...1).contains(point.y), "\(blueprint.id.rawValue) y out of range")
            }
        }
    }

    func testInitialStatesAreClean() {
        let states = RegionCatalog.initialStates()
        XCTAssertEqual(states.count, RegionID.allCases.count)
        for (id, state) in states {
            XCTAssertEqual(state.id, id)
            XCTAssertEqual(state.infected, 0)
            XCTAssertEqual(state.lost, 0)
            XCTAssertEqual(state.awareness, 0)
            XCTAssertFalse(state.isInfected)
            XCTAssertFalse(state.isSaturated)
            XCTAssertNil(state.firstInfectedDay)
        }
    }

    func testStartRegionRespectsScenarioAndIsDeterministic() {
        for scenario in StartScenario.allCases {
            var first = SeededGenerator(seed: 555)
            var second = SeededGenerator(seed: 555)
            let a = RegionCatalog.startRegion(for: scenario, using: &first)
            let b = RegionCatalog.startRegion(for: scenario, using: &second)
            XCTAssertEqual(a, b)

            switch scenario {
            case .isolatedIsland:
                XCTAssertTrue(RegionCatalog.lowConnectivityStarts.contains(a))
            case .transitHub:
                XCTAssertTrue(RegionCatalog.hubStarts.contains(a))
            case .wildcard:
                XCTAssertTrue(RegionCatalog.blueprint(a).isStartCandidate)
            }
        }
    }
}

final class TraitCatalogTests: XCTestCase {

    func testEveryTraitIDHasANode() {
        for id in TraitID.allCases {
            XCTAssertEqual(TraitCatalog.trait(id).id, id)
        }
        XCTAssertEqual(TraitCatalog.all.count, TraitID.allCases.count)
    }

    func testBranchesPartitionTheTree() {
        let branchTotal = TraitCategory.allCases
            .reduce(0) { $0 + TraitCatalog.traits(in: $1).count }
        XCTAssertEqual(branchTotal, TraitCatalog.all.count)
        for category in TraitCategory.allCases {
            for trait in TraitCatalog.traits(in: category) {
                XCTAssertEqual(trait.category, category)
            }
        }
    }

    func testPrerequisitesExistStayInBranchAndAreAcyclic() {
        for trait in TraitCatalog.all {
            for requirement in trait.prerequisites {
                let parent = TraitCatalog.trait(requirement)
                XCTAssertEqual(
                    parent.category, trait.category,
                    "\(trait.id.rawValue) depends across branches"
                )
                XCTAssertLessThanOrEqual(
                    parent.cost, trait.cost,
                    "\(trait.id.rawValue) is cheaper than its own prerequisite"
                )
            }
            XCTAssertFalse(trait.prerequisites.contains(trait.id))
            XCTAssertFalse(
                hasCycle(from: trait.id, seen: []),
                "\(trait.id.rawValue) sits on a dependency cycle"
            )
        }
    }

    private func hasCycle(from id: TraitID, seen: Set<TraitID>) -> Bool {
        if seen.contains(id) { return true }
        var visited = seen
        visited.insert(id)
        return TraitCatalog.trait(id).prerequisites.contains { hasCycle(from: $0, seen: visited) }
    }

    func testEveryBranchHasAFreeEntryPoint() {
        for category in TraitCategory.allCases {
            let roots = TraitCatalog.traits(in: category).filter { $0.prerequisites.isEmpty }
            XCTAssertFalse(roots.isEmpty, "\(category.rawValue) has no reachable entry node")
        }
    }

    func testCostsAndRefundsAreSane() {
        for trait in TraitCatalog.all {
            XCTAssertGreaterThan(trait.cost, 0)
            XCTAssertGreaterThan(trait.refund, 0)
            XCTAssertLessThan(trait.refund, trait.cost, "\(trait.id.rawValue) refunds its full cost")
            XCTAssertTrue((0...1).contains(trait.mapPosition.x))
            XCTAssertTrue((0...1).contains(trait.mapPosition.y))
        }
    }

    func testEffectsSumIsOrderIndependent() {
        let a = TraitCatalog.trait(.aerosolI).effects
        let b = TraitCatalog.trait(.spectralFever).effects
        XCTAssertEqual(a + b, b + a)
    }

    func testDriftPoolIsUsable() {
        XCTAssertFalse(TraitCatalog.driftPool.isEmpty)
        for id in TraitCatalog.driftPool {
            XCTAssertEqual(TraitCatalog.trait(id).category, .symptoms)
            XCTAssertTrue(TraitCatalog.trait(id).prerequisites.isEmpty)
        }
    }

    func testProfileClampsStackedModifiers() {
        // Stacking every stealth source must not push awareness growth negative.
        let profile = Fixture.profile([.mimicryI, .mimicryII, .dormancy], strain: .halo)
        XCTAssertLessThanOrEqual(profile.stealth, 0.85)
        XCTAssertGreaterThanOrEqual(profile.stealth, 0)

        let researchProfile = Fixture.profile([.driftCodingI, .driftCodingII])
        XCTAssertLessThanOrEqual(researchProfile.researchResistance, 0.75)
    }

    func testClimateFactorNeverCollapsesToZeroOrRunsAway() {
        for climate in Climate.allCases {
            let bare = Fixture.profile([])
            XCTAssertGreaterThan(bare.climateFactor(for: climate), 0)
            XCTAssertLessThanOrEqual(bare.climateFactor(for: climate), 2.5)

            let hardened = Fixture.profile([
                .cryoCoatI, .cryoCoatII, .thermalShellI, .thermalShellII, .environmentalHardening
            ])
            XCTAssertLessThanOrEqual(hardened.climateFactor(for: climate), 2.5)
        }
    }
}

final class StrainCatalogTests: XCTestCase {

    func testEveryStrainIDHasADefinition() {
        for id in StrainID.allCases {
            XCTAssertEqual(StrainCatalog.strain(id).id, id)
        }
        XCTAssertEqual(StrainCatalog.all.count, StrainID.allCases.count)
    }

    func testAtLeastFourStrainsNeedNoUnlock() {
        XCTAssertGreaterThanOrEqual(StrainCatalog.freeStrains.count, 4)
        XCTAssertTrue(StrainCatalog.freeStrains.allSatisfy { !$0.requiresUnlock })
    }

    func testPointMultipliersArePositive() {
        for strain in StrainCatalog.all {
            XCTAssertGreaterThan(strain.pointIncomeMultiplier, 0)
        }
    }

    func testSignaturesAreDistinctEnoughToMatter() {
        let signatures = Set(StrainCatalog.all.map(\.signature))
        XCTAssertGreaterThanOrEqual(signatures.count, 4)
    }
}
