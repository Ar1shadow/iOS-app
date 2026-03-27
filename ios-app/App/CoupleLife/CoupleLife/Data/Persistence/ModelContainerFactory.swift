import SwiftData

enum ModelContainerFactory {
    static func make() throws -> ModelContainer {
        let schema = Schema([
            Record.self,
            TaskItem.self,
            HealthMetricSnapshot.self
        ])

        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

