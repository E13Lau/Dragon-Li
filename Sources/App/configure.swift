import Fluent
import Leaf
import Vapor
import FluentSQLiteDriver

// configures your application
public func configure(_ app: Application) throws {
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    
    app.views.use(.leaf)
    app.leaf.cache.isEnabled = app.environment.isRelease
    
    app.databases.use(.sqlite(.file("Database/db.sqlite")), as: .sqlite)
    
    app.migrations.add(CreatePackage())
    try app.autoMigrate().wait()
    
    app.http.server.configuration.port = Int(Environment.get("port") ?? "13134") ?? 13134
    app.http.server.configuration.hostname = "0.0.0.0"

    // register routes
    try routes(app)
}
