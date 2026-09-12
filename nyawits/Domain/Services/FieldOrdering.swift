import Foundation

enum FieldOrdering {
    static func sortFields(_ fields: [MappedField]) -> [MappedField] {
        fields.sorted {
            if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
