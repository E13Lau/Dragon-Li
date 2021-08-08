import Vapor

// MARK: Helpers for naming files

/// Intended entry point for naming files
/// - Parameter headers: Source `HTTPHeaders`
/// - Returns: `String` with best guess file name.
func filename(with headers: HTTPHeaders) -> String {
    let fileNameHeader = headers["file-name"]
    if let inferredName = fileNameHeader.first {
        return inferredName
    }
    
    let fileExt = fileExtension(for: headers)
    return "upload-\(UUID().uuidString).\(fileExt)"
}

func packageNameWith(header: HTTPHeaders) -> String {
    if let string = header["pkg-name"].first {
        return string
    }
    return "unknown"
}

func packageVersion(with header: HTTPHeaders) -> String {
    if let string = header["pkg-version"].first {
        return string
    }
    return "0.0.0"
}

func packageBuildNumber(with header: HTTPHeaders) -> String {
    if let string = header["pkg-build"].first {
        return string
    }
    return "0"
}

func packageBundleID(with header: HTTPHeaders) -> String {
    if let string = header["pkg-id"].first {
        return string
    }
    return "unknown"
}

func packageDescription(with header: HTTPHeaders) -> String? {
    return header["pkg-des"].first
}

/// Parse the header’s Content-Type to determine the file extension
/// - Parameter headers: source `HTTPHeaders`
/// - Returns: `String` guess at appropriate file extension
func fileExtension(for headers: HTTPHeaders) -> String {
    var fileExtension = "tmp"
    if let contentType = headers.contentType {
        switch contentType {
        case .jpeg:
            fileExtension = "jpg"
        case .mp3:
            fileExtension = "mp3"
        case .init(type: "video", subType: "mp4"):
            fileExtension = "mp4"
        case .init(type: "application", subType: "vnd.iphone"):
            fileExtension = "ipa"
        case .init(type: "application", subType: "octet-stream"):
            fileExtension = "ipa"
        case .init(type: "application", subType: "vnd.android.package-archive"):
            fileExtension = "apk"
        default:
            fileExtension = "bits"
        }
    }
    return fileExtension
}

/// Creates the upload directory as part of the working directory
/// - Parameters:
///   - directoryName: sub-directory name
///   - app: Application
/// - Returns: name of the directory
func configureUploadDirectory(named directoryName: String = "Uploads/", for app: Application) -> EventLoopFuture<String> {
    let createdDirectory = app.eventLoopGroup.next().makePromise(of: String.self)
    var uploadDirectoryName = app.directory.workingDirectory
    if directoryName.last != "/" {
        uploadDirectoryName += "/"
    }
    uploadDirectoryName += directoryName
    do {
        try FileManager.default.createDirectory(atPath: uploadDirectoryName,
                                                withIntermediateDirectories: true,
                                                attributes: nil)
        createdDirectory.succeed(uploadDirectoryName)
    } catch {
        createdDirectory.fail(FileError.couldNotSave)
    }
    return createdDirectory.futureResult
}

enum FileError: Error {
    case couldNotSave
}

