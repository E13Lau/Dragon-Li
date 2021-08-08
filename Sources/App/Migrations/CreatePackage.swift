import Fluent

struct CreatePackage: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Package.schema)
            .id()
            .field("file_name", .string, .required)
            .field("package_name", .string, .required)
            .field("version", .string, .required)
            .field("build", .string, .required)
            .field("platform", .string, .required)
            .field("created_at", .datetime, .required)
            .field("bundle_id", .string)
            .field("description", .string)
            .field("dsym_name", .string)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema(Package.schema).delete()
    }
}
