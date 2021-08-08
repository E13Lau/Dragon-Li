import Fluent
import Vapor
import Foundation

struct UplaodController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.on(.POST, "upload", body: .stream, use: upload)
        routes.on(.POST, "upload", "dsym", body: .stream, use: uploadDSYM)
        routes.on(.POST, "upload", "report", body: .stream, use: uploadReport)
        routes.on(.GET, "download", ":fileID", ":fileName", use: downloadFile)
        routes.on(.GET, "upload", use: index)
        routes.on(.GET, "rootca", use: getRootCA)
    }
    
    enum Platform: String, Codable {
        
        case iOS, Android
        init?(with fileExtension: String) {
            switch fileExtension {
            case "ipa":
                self = .iOS
            case "apk":
                self = .Android
            default:
                return nil
            }
        }
    }

    struct UploadFile: Content {
        var name: String
        var file: File
        var type: Platform
    }
    
    func index(req: Request) throws -> EventLoopFuture<[Package]> {
        Package.query(on: req.db).all()
    }
    
    ///根据fileID查数据库取得FileName再重定向
    func downloadFile(req: Request) throws -> EventLoopFuture<Response> {
        //两次查数据库，有没有其他方法？
        //直接在下载地址加入名称
        guard let fileID = req.parameters.get("fileID") else {
            return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        guard let fileName = req.parameters.get("fileName") else {
            return req.eventLoop.makeFailedFuture(Abort(.notFound))
        }
        let path = "\(req.application.directory.workingDirectory)Uploads/\(fileID)/\(fileName)"
        return req.eventLoop.makeSucceededFuture(req.fileio.streamFile(at: path ))
    }
    
    ///根据fileID查数据库取得文件地址下载
    func downloadFileWithFileID(req: Request) throws -> EventLoopFuture<Response> {
        try getFile(req: req).map({ file -> Response in
            req.fileio.streamFile(at: file.filePath(for: req.application) )
        })
    }
    
    func uploadReport(req: Request) throws -> EventLoopFuture<HTTPResponseStatus> {
        let statusPromise = req.eventLoop.makePromise(of: HTTPResponseStatus.self)
        guard let id = req.headers["id"].first else {
            statusPromise.fail(Abort(.notFound))
            return statusPromise.futureResult
        }
        let fileName = "tests.html"
        let fileDirPath = req.application.directory.workingDirectory + "Uploads/" + "\(id)/"
        let filePath = fileDirPath + fileName
        try? createDirectoryIfNeed(path: fileDirPath)
        try? createPkgFile(path: filePath)
        
        let nbFileIO = NonBlockingFileIO(threadPool: req.application.threadPool)
        let fileHandle = nbFileIO.openFile(path: filePath, mode: .write, eventLoop: req.eventLoop)
        return fileHandle.map { (handle) in
            req.body.drain { (result) -> EventLoopFuture<Void> in
                let drainPromise = req.eventLoop.makePromise(of: Void.self)
                switch result {
                case .buffer(let buffer):
                    let a = nbFileIO.write(fileHandle: handle, buffer: buffer, eventLoop: req.eventLoop)
                    _ = a.always { (outcome) in
                        switch outcome {
                        case .success(let yep):
                            drainPromise.succeed(yep)
                        case .failure(let err):
                            drainPromise.fail(err)
                        }
                    }
                case .error(let errz):
                    do {
                        drainPromise.fail(errz)
                        try handle.close()
                        try FileManager.default.removeItem(atPath: filePath)
                    } catch {
                        req.logger.debug("catastrophic failure on \(errz) \(error)")
                    }
                    statusPromise.fail(errz)
                case .end:
                    drainPromise.succeed(())
                    statusPromise.succeed(.ok)
                    do {
                        try handle.close()
                    } catch {
                        req.logger.debug("\(error)")
                    }
                }
                return drainPromise.futureResult
            }
        }.transform(to: statusPromise.futureResult)
    }
    
    ///DSYM压缩为zip后上传
    func uploadDSYM(req: Request) throws -> EventLoopFuture<String> {
        let statusPromise = req.eventLoop.makePromise(of: String.self)
        
        guard let id = req.headers["id"].first else {
            statusPromise.fail(Abort(.notFound))
            return statusPromise.futureResult
        }
        let fileName = "dsym.zip"
        let fileDirPath = req.application.directory.workingDirectory + "Uploads/" + "\(id)/"
        let filePath = fileDirPath + fileName
        try createDirectoryIfNeed(path: fileDirPath)
        try createPkgFile(path: filePath)
        
        let nbFileIO = NonBlockingFileIO(threadPool: req.application.threadPool)
        let fileHandle = nbFileIO.openFile(path: filePath, mode: .write, eventLoop: req.eventLoop)
        return fileHandle.map { (handle) in
            req.body.drain { (result) -> EventLoopFuture<Void> in
                let drainPromise = req.eventLoop.makePromise(of: Void.self)
                switch result {
                case .buffer(let buffer):
                    let a = nbFileIO.write(fileHandle: handle, buffer: buffer, eventLoop: req.eventLoop)
                    _ = a.always { (outcome) in
                        switch outcome {
                        case .success(let yep):
                            drainPromise.succeed(yep)
                        case .failure(let err):
                            drainPromise.fail(err)
                        }
                    }
                case .error(let errz):
                    do {
                        drainPromise.fail(errz)
                        try handle.close()
                        try FileManager.default.removeItem(atPath: filePath)
                    } catch {
                        req.logger.debug("catastrophic failure on \(errz) \(error)")
                    }
                    statusPromise.fail(errz)
                case .end:
                    drainPromise.succeed(())
                    // TODO 更新Package xml 地址
                    statusPromise.succeed(id)
                    do {
                        try handle.close()
                    } catch {
                        req.logger.debug("\(error)")
                    }
                }
                return drainPromise.futureResult
            }
        }.transform(to: statusPromise.futureResult)
    }
    
    func upload(req: Request) throws -> EventLoopFuture<String> {
        let statusPromise = req.eventLoop.makePromise(of: String.self)
        
        do {
            let package = try Package(req: req)
            let filePath = package.filePath(for: req.application)
            let fileDirPath = package.fileDir(for: req.application)
            
            try createDirectoryIfNeed(path: fileDirPath)
            try createPkgFile(path: filePath)
            
            let nbFileIO = NonBlockingFileIO(threadPool: req.application.threadPool)
            let fileHandle = nbFileIO.openFile(path: filePath, mode: .write, eventLoop: req.eventLoop)
            return fileHandle.map { (handle) in
                req.body.drain { (result) -> EventLoopFuture<Void> in
                    let drainPromise = req.eventLoop.makePromise(of: Void.self)
                    switch result {
                    case .buffer(let buffer):
                        let a = nbFileIO.write(fileHandle: handle, buffer: buffer, eventLoop: req.eventLoop)
                        _ = a.always { (outcome) in
                            switch outcome {
                            case .success(let yep):
                                drainPromise.succeed(yep)
                            case .failure(let err):
                                drainPromise.fail(err)
                            }
                        }
                    case .error(let errz):
                        do {
                            drainPromise.fail(errz)
                            try handle.close()
                            try FileManager.default.removeItem(atPath: filePath)
                        } catch {
                            req.logger.debug("catastrophic failure on \(errz) \(error)")
                        }
                        statusPromise.fail(errz)
                    //                    statusPromise.succeed(.internalServerError)
                    case .end:
                        drainPromise.succeed(())
                        do {
                            try handle.close()
                        } catch {
                            req.logger.debug("\(error)")
                            statusPromise.fail(Abort.init(.internalServerError))
                        }
                        //TODO #upzip
                        switch package.platform {
                        case Platform.iOS.rawValue:
                            _ = package.save(on: req.db)
                            statusPromise.succeed(package.id!.uuidString)
                        case Platform.Android.rawValue:
                            _ = package.save(on: req.db)
                            statusPromise.succeed(package.id!.uuidString)
                        default:
                            statusPromise.fail(Abort.init(.internalServerError))
                        }
                    }
                    return drainPromise.futureResult
                }
            }.transform(to: statusPromise.futureResult)

        } catch {
            statusPromise.fail(Abort.init(.internalServerError))
            return req.eventLoop.makeFailedFuture(Abort.init(.internalServerError))
        }
    }
    
    func getRootCA(req: Request) throws -> EventLoopFuture<Response> {
        return req.eventLoop.makeSucceededFuture(req.fileio.streamFile(at: "./certs/rootCA_cert.pem"))
    }
}

func createDirectoryIfNeed(path: String) throws {
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
}

func createPkgFile(path: String) throws {
    if FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) == false {
        throw Abort(.internalServerError)
    }
}

///上传文件目录
func directory(for app: Application, name: String) -> String {
    app.directory.workingDirectory + "Uploads/" + name
}

///通过ID查询Package记录
func getFile(req: Request) throws -> EventLoopFuture<Package> {
    Package.find(req.parameters.get("fileID"), on: req.db).unwrap(or: Abort(.notFound))
}
