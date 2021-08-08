//
//  File.swift
//  
//
//  Created by lau on 2020/5/2.
//

import Fluent
import Vapor
import Foundation

struct PackageQuery: Content {
    //Package Version
    var v: String?
    //Build Number
    var b: String?
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

final class Package: Model, Content {
    static let schema = "package"
    
    @ID(key: .id)
    var id: UUID?
    
    ///项目名
    @Field(key: "package_name")
    var packageName: String
    
    @Field(key: "file_name")
    var fileName: String
    
    ///平台
    @Field(key: "platform")
    var platform: String
    
    ///版本
    @Field(key: "version")
    var version: String
    
    ///构建版本
    @Field(key: "build")
    var build: String
    
    @Field(key: "bundle_id")
    var bundleID: String
    
    ///iOS dsym 文件名称
    @Field(key: "dsym_name")
    var dsym: String?
    
    ///描述
    @Field(key: "description")
    var description: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdDate: Date?
    
    init() { }

    init(id: UUID? = nil, packageName: String, fileName: String, version: String, build: String, platform: String, bundleID: String) {
        self.id = id
        self.packageName = packageName
        self.fileName = fileName
        self.version = version
        self.build = build
        self.platform = platform
        self.bundleID = bundleID
        self.createdDate = Date()
        self.dsym = "dsym.zip"
    }
    
    init(req: Request) throws {
        let fileExt = fileExtension(for: req.headers)
        guard let platform = Platform(with: fileExt) else {
            throw Abort(.unsupportedMediaType)
        }
        self.id = UUID()
        self.packageName = packageNameWith(header: req.headers)
        self.fileName = filename(with: req.headers)
        self.version = packageVersion(with: req.headers)
        self.build = packageBuildNumber(with: req.headers)
        self.bundleID = packageBundleID(with: req.headers)
        self.description = packageDescription(with: req.headers)
        self.platform = platform.rawValue
        self.dsym = "dsym.zip"
        self.createdDate = Date()
    }
    
    public func fileDir(for app: Application) -> String {
        app.directory.workingDirectory + "Uploads/" + "\(id!.uuidString)/"
    }
    
    public func filePath(for app: Application) -> String {
        fileDir(for: app) + fileName
    }
    
    public func deleteDir(for app: Application) throws {
        try FileManager.default.removeItem(atPath: self.fileDir(for: app))
    }

    
}

enum ProjectPlatform: String, Codable {
    case ios, android
}
