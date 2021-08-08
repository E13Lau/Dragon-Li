import Fluent
import FluentSQL
import Vapor

class WebController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("", use: main)
        routes.get("detail", use: detail)
        routes.get("404") {
            $0.view.render("404")
        }
        routes.get("mobileconfig", ":", use: getUDIDMobileConfig)
        routes.post("udid", use: getUDID)
        routes.get("udid", use: udid)
        routes.get("install", ":fileID", ":", use: getInstallPlist)
        routes.get("test-report", ":pkgID", use: testReport)
    }
    
    struct UDIDContext: Content {
        let imei: String
        let product: String
        let udid: String
        let version: String
    }

    struct MainContext: Content {
        let items: [Package]
    }
    struct DetailContext: Content {
        var isDetail: Bool = true
        let item: Package
        ///第一条是顶部
        let items: [Package]
    }
        
    func main(req: Request) throws -> EventLoopFuture<View> {
        guard let sql = req.db as? SQLDatabase else {
            throw Abort(.forbidden)
        }
        return sql
            .raw("SELECT * FROM (SELECT * FROM Package ORDER BY created_at DESC) temp_table GROUP BY bundle_id, platform ORDER BY created_at DESC;")
            .all(decoding: Package.self)
            .flatMap({ req.view.render("main", MainContext(items: $0)) })
    }
    
    ///根据id 和 platform获取所有的 pakcage
    func detail(req: Request) throws -> EventLoopFuture<Response> {
        struct Query: Content {
            //platform
            let p: String
            //bundleID
            let b: String
        }
        let q = try req.query.decode(Query.self)
        // 判断是否含有两个参数，没有跳转到Main
        guard q.p != "" && q.b != "" else {
//            return try main(req: req)
            return req.eventLoop.future(req.redirect(to: "/"))
        }
        let packages = Package.query(on: req.db)
            .group(.and, {
                $0.filter(\.$bundleID == q.b).filter(\.$platform == q.p)
            })
            .sort(\.$createdDate, .descending)
        return packages.all()
            .flatMap({ (items) -> EventLoopFuture<Response> in
                guard let item = items.first else {
                    return req.redirect(to: "/").encodeResponse(for: req)
                }
                return req.view.render("detail", DetailContext.init(item: item, items: Array(items.dropFirst() ) ) ).encodeResponse(for: req)
            })
    }
    
    ///udid 结果页面
    func udid(req: Request) throws -> EventLoopFuture<View> {
        let context = try req.query.decode(UDIDContext.self)
        return req.view.render("udid", context)
    }
    
    ///iOS POST UDID 数据接口
    func getUDID(req: Request) throws -> EventLoopFuture<Response> {
        req.logger.debug("\(req.description)")
        //            application/pkcs7-signature
        
        guard let string = req.body.string else {
            throw Abort(.notFound)
        }
        guard let start = string.range(of: "<?xml") else {
            throw Abort(.notFound)
        }
        guard let end = string.range(of: #"</plist>"#) else {
            throw Abort(.notFound)
        }
        let xmlstring = String(string[start.lowerBound..<end.upperBound])
        req.logger.debug("\(xmlstring)")
        guard let data = xmlstring.data(using: .utf8) else {
            throw Abort(.notFound)
        }
        do {
            guard let xml = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
                throw Abort(.notFound)
            }
            let context = UDIDContext(imei: xml["IMEI"] ?? "", product: xml["PRODUCT"] ?? "", udid: xml["UDID"] ?? "", version: xml["VERSION"] ?? "")
            return req.redirect(to: "/udid?imei=\(context.imei)&product=\(context.product)&udid=\(context.udid)&version=\(context.version)", type: .permanent).encodeResponse(for: req)
        } catch {
            throw Abort(.notFound)
        }
    }
    
    //获取install plist 文件
    func getInstallPlist(req: Request) throws -> EventLoopFuture<Response> {
        let host = try requestHost(req: req)
        return try getFile(req: req)
            .flatMap({ (pkg) -> EventLoopFuture<String> in
                do {
                    return try readInstallPlistTemplate(req: req)
                        .map({ (string) -> (String) in
                            return replaceInstallPlist(content: string, host: host, pkg: pkg)
                        })
                } catch {
                    return req.eventLoop.makeFailedFuture(Abort.init(.internalServerError))
                }
            })
            .map({ XML(value: $0) })
            .encodeResponse(for: req)
    }
    
    ///获取 UDID 的描述文件
    func getUDIDMobileConfig(req: Request) throws -> EventLoopFuture<Response> {
        try readMobileconfigTemplate(req: req)
            .flatMapThrowing({ (string) -> String in
                let host = try requestHost(req: req)
                return replaceMobileconfig(content: string, host: host)
            })
            .map({ XML(value: $0) })
            .encodeResponse(for: req)
    }
    
    func testReport(req: Request) throws -> EventLoopFuture<Response> {
        guard let pkgID = req.parameters.get("pkgID") else {
            return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        let path = "\(req.application.directory.workingDirectory)Uploads/\(pkgID)/tests.html"
        return req.eventLoop.makeSucceededFuture(req.fileio.streamFile(at: path ))
    }
}

func requestHost(req: Request) throws -> String {
    guard let host = req.headers["Host"].first else {
        throw Abort(HTTPStatus.badRequest)
    }
    return host
}

func readInstallPlistTemplate(req: Request) throws -> EventLoopFuture<String> {
    try readTemplate(filename: "template.plist", req: req)
}

func readMobileconfigTemplate(req: Request) throws -> EventLoopFuture<String> {
    try readTemplate(filename: "udid.mobileconfig", req: req)
}

func readTemplate(filename: String, req: Request) throws -> EventLoopFuture<String> {
    let path = "\(req.application.directory.workingDirectory)/Template/\(filename)"
    return req.fileio.collectFile(at: path)
        .map { (buffer) -> (String) in
            var buffer = buffer
            return buffer.readString(length: buffer.readableBytes)!
        }
}

func replaceInstallPlist(content: String, host: String, pkg: Package) -> String {
    var newString = content
    newString = newString.replacingOccurrences(of: "$(pkg_url)", with: "https://\(host)/download/\(pkg.id!)/\(pkg.fileName)")
    newString = newString.replacingOccurrences(of: "$(bundle_id)", with: pkg.bundleID)
    newString = newString.replacingOccurrences(of: "$(bundle_version)", with: pkg.version)
    newString = newString.replacingOccurrences(of: "$(subtitle)", with: pkg.version)
    newString = newString.replacingOccurrences(of: "$(title)", with: "\(pkg.packageName)")
    return newString
}

func replaceMobileconfig(content: String, host: String) -> String {
    return content.replacingOccurrences(of: "$(host)", with: host)
}

struct XML {
    let value: String
}

extension XML: ResponseEncodable {
    public func encodeResponse(for request: Request) -> EventLoopFuture<Response> {
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/xml")
        return request.eventLoop.makeSucceededFuture(.init(
            status: .ok, headers: headers, body: .init(string: value)
        ))
    }
}
