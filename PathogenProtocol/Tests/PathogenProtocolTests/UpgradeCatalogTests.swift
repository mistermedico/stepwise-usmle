import XCTest
@testable import PathogenProtocol

final class UpgradeCatalogTests: XCTestCase {

    func testNoDuplicateNodeIDs() {
        let ids = UpgradeCatalog.allNodes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryPrerequisiteExists() {
        for node in UpgradeCatalog.allNodes {
            guard let prerequisiteID = node.prerequisiteID else { continue }
            XCTAssertNotNil(UpgradeCatalog.node(prerequisiteID), "\(node.id) references missing prerequisite \(prerequisiteID)")
        }
    }

    func testEveryPrerequisiteIsInTheSameCategory() {
        for node in UpgradeCatalog.allNodes {
            guard let prerequisiteID = node.prerequisiteID, let prerequisite = UpgradeCatalog.node(prerequisiteID) else { continue }
            XCTAssertEqual(prerequisite.category, node.category)
            XCTAssertEqual(prerequisite.tier, node.tier - 1, "\(node.id) must directly follow its prerequisite's tier")
        }
    }

    func testEachCategoryHasExactlyOneRootNode() {
        for category in UpgradeCategory.allCases {
            let roots = UpgradeCatalog.allNodes.filter { $0.category == category && $0.prerequisiteID == nil }
            XCTAssertEqual(roots.count, 1, "\(category) should have exactly one tier-1 root node")
        }
    }

    func testCostsIncreaseWithTier() {
        for category in UpgradeCategory.allCases {
            let nodes = UpgradeCatalog.allNodes.filter { $0.category == category }.sorted { $0.tier < $1.tier }
            for (a, b) in zip(nodes, nodes.dropFirst()) {
                XCTAssertLessThan(a.cost, b.cost, "\(b.id) should cost more than \(a.id)")
            }
        }
    }

    // Symptoms branch trade-off: higher tiers must raise both lethality AND severity
    // together (the visibility cost the design spec calls for), never lethality alone.
    func testSymptomsBranchTradesLethalityForVisibility() {
        let nodes = UpgradeCatalog.allNodes.filter { $0.category == .symptoms }.sorted { $0.tier < $1.tier }
        for (a, b) in zip(nodes, nodes.dropFirst()) {
            XCTAssertLessThan(a.effect.lethalityBonus, b.effect.lethalityBonus)
            XCTAssertLessThan(a.effect.severityBonus, b.effect.severityBonus)
        }
    }
}
