import Fluent
import FluentSQL
import Vapor

class ApiController: RouteCollection {
    struct ListItem: Content {
        let packageName: String?
        let fileName: String?
        let platform: String?
        let version: String?
        let build: String?
        let bundleID: String?
        let id: String?
        
        init(with package: Package) {
            self.packageName = package.packageName
            self.fileName = package.fileName
            self.platform = package.platform
            self.version = package.version
            self.build = package.build
            self.bundleID = package.bundleID
            self.id = package.id?.uuidString
        }
    }

    func boot(routes: RoutesBuilder) throws {
        let group = routes.grouped("api")
        group.get("list", use: list)
        group.delete(":id", use: delete)
    }
    
    // GET api/list?n=""&p=""&v=""
    func list(req: Request) throws -> EventLoopFuture<[ListItem]> {
        struct Param: Content {
            let n: String?
            let p: String?
            let v: String?
        }
        let query = try req.query.decode(Param.self)
        var package = Package.query(on: req.db)
        if let name = query.n {
            package = package.filter(\.$packageName == name)
        }
        if let platform = query.p {
            package = package.filter(\.$platform == platform)
        }
        if let v = query.v {
            package = package.filter(\.$version == v)
        }
        return package.sort(\.$createdDate, .descending).all().mapEach({ (package) -> ListItem in
            return ListItem(with: package)
        })
    }
    
    // DELETE api/:id
    func delete(req: Request) throws -> EventLoopFuture<HTTPStatus> {
        guard let id = req.parameters.get("id") else {
            return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        return Package.find(UUID(uuidString: id), on: req.db)
            .unwrap(or: Abort(.notFound))
            .always({ (result) in
                switch result {
                case .success(let value):
                    try? value.deleteDir(for: req.application)
                case .failure(let err):
                    req.logger.error("\(err.localizedDescription)")
                }
            })
            .flatMap {
                return $0.delete(on: req.db)
            }
            .transform(to: .ok)
    }

}

