import Foundation

struct Curriculum: Codable {
    let version: String
    let language: String
    let status: String
    let modules: [StudyModule]
    let units: [StudyUnit]
    let questions: [StudyQuestion]
    let references: [StudyReference]

    static func load(bundle: Bundle = .main) throws -> Curriculum {
        guard let url = bundle.url(forResource: "curriculum", withExtension: "json") else {
            throw CurriculumError.missingResource
        }
        let curriculum = try JSONDecoder().decode(Curriculum.self, from: Data(contentsOf: url))
        try curriculum.validate()
        return curriculum
    }

    func validate() throws {
        let unitIDs = Set(units.map(\.id))
        let questionIDs = Set(questions.map(\.id))
        guard modules.count == 12, units.count == 240, questions.count == 480,
              unitIDs.count == units.count, questionIDs.count == questions.count,
              Set(modules.map(\.id)).count == modules.count else { throw CurriculumError.invalidStructure }
        for module in modules {
            guard module.unitIds.count == 20, Set(module.unitIds).count == 20,
                  module.unitIds.allSatisfy({ id in units.contains { $0.id == id && $0.topic == module.id } }),
                  questions.filter({ $0.topic == module.id }).count == 40 else { throw CurriculumError.invalidStructure }
        }
        for unit in units {
            guard modules.contains(where: { $0.id == unit.topic }),
                  questions.filter({ $0.unitId == unit.id }).count == 2 else { throw CurriculumError.invalidStructure }
        }
        for question in questions {
            guard question.a.count == 4, Set(question.a).count == 4,
                  question.a.indices.contains(question.correct), question.rationales.count == 4,
                  units.contains(where: { $0.id == question.unitId && $0.topic == question.topic }) else {
                throw CurriculumError.invalidStructure
            }
        }
    }

    func unit(_ id: String) -> StudyUnit? { units.first { $0.id == id } }
    func module(_ id: Int) -> StudyModule? { modules.first { $0.id == id } }
    func questions(for unit: StudyUnit) -> [StudyQuestion] { questions.filter { $0.unitId == unit.id } }
}

enum CurriculumError: Error { case missingResource, invalidStructure }

struct StudyModule: Codable, Identifiable {
    let id: Int
    let title: String
    let unitIds: [String]
    let description: String
}

struct StudyUnit: Codable, Identifiable {
    let id: String
    let topic: Int
    let number: Int
    let title: String
    let mechanism: String
    let `case`: String
    let pitfall: String
    let objective: String
    let reviewStatus: String
    let references: [String]
}

struct StudyQuestion: Codable, Identifiable {
    let id: String
    let unitId: String
    let topic: Int
    let kind: String
    let q: String
    let a: [String]
    let correct: Int
    let why: String
    let rationales: [String]
    let takeaway: String
    let reviewStatus: String
}

struct StudyReference: Codable, Identifiable {
    let id: String
    let title: String
    let url: String
    let role: String
    let checked: String?
}
