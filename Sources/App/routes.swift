import Fluent
import Vapor

func routes(_ app: Application) throws {
    let group = app.grouped(WebErrorMiddleware.default(environment: app.environment))
    try group.register(collection: WebController())
    try app.register(collection: UplaodController())
    try app.register(collection: ApiController())
}
