//
//  ExportDirectoryService.swift
//  Egangnal
//

import Foundation

struct ExportDirectorySelection: Equatable, Sendable {
    let bookmarkData: Data
    let displayPath: String
}

enum ExportDirectoryPath {
    static func displayPath(for directoryURL: URL) -> String {
        var path = directoryURL.path(percentEncoded: false)
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}

enum PreferredDirectoryExportResult: Equatable, Sendable {
    case exported(url: URL, refreshedBookmarkData: Data?)
    case unavailable
}

enum ExportDirectoryError: LocalizedError, Equatable, Sendable {
    case invalidDirectory
    case invalidFilename
    case tooManyDuplicateFiles

    var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            "请选择一个有效的文件夹。"
        case .invalidFilename:
            "模板文件名无效。"
        case .tooManyDuplicateFiles:
            "默认文件夹内存在过多同名模板，请整理后重试。"
        }
    }
}

@MainActor
protocol ExportDirectoryService {
    func makeSelection(for directoryURL: URL) throws -> ExportDirectorySelection
    func export(
        data: Data,
        preferredFilename: String,
        using bookmarkData: Data
    ) throws -> PreferredDirectoryExportResult
}

@MainActor
final class SecurityScopedExportDirectoryService: ExportDirectoryService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func makeSelection(for directoryURL: URL) throws -> ExportDirectorySelection {
        guard directoryURL.isFileURL else {
            throw ExportDirectoryError.invalidDirectory
        }

        let didAccess = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try directoryURL.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else {
            throw ExportDirectoryError.invalidDirectory
        }

        let bookmarkData = try directoryURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.isDirectoryKey],
            relativeTo: nil
        )
        return ExportDirectorySelection(
            bookmarkData: bookmarkData,
            displayPath: ExportDirectoryPath.displayPath(for: directoryURL)
        )
    }

    func export(
        data: Data,
        preferredFilename: String,
        using bookmarkData: Data
    ) throws -> PreferredDirectoryExportResult {
        var isStale = false
        let directoryURL: URL
        do {
            directoryURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            // 书签失效时交回系统保存面板，避免阻断用户导出。
            return .unavailable
        }

        guard directoryURL.startAccessingSecurityScopedResource() else {
            return .unavailable
        }
        defer {
            directoryURL.stopAccessingSecurityScopedResource()
        }

        guard let values = try? directoryURL.resourceValues(
            forKeys: [.isDirectoryKey, .isWritableKey]
        ),
              values.isDirectory == true,
              values.isWritable == true else {
            return .unavailable
        }

        // 先选名再写入存在竞态，使用独占写入并在撞名时重新选名。
        var destination = try Self.availableDestination(
            in: directoryURL,
            preferredFilename: preferredFilename,
            fileManager: fileManager
        )
        var didWrite = false
        for _ in 0..<10_000 {
            do {
                try data.write(
                    to: destination,
                    options: [.atomic, .withoutOverwriting]
                )
                didWrite = true
                break
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                destination = try Self.availableDestination(
                    in: directoryURL,
                    preferredFilename: preferredFilename,
                    fileManager: fileManager
                )
            }
        }
        guard didWrite else {
            throw ExportDirectoryError.tooManyDuplicateFiles
        }

        let refreshedBookmark: Data?
        if isStale {
            refreshedBookmark = try? directoryURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: [.isDirectoryKey],
                relativeTo: nil
            )
        } else {
            refreshedBookmark = nil
        }

        return .exported(
            url: destination,
            refreshedBookmarkData: refreshedBookmark
        )
    }

    static func availableDestination(
        in directoryURL: URL,
        preferredFilename: String,
        fileManager: FileManager
    ) throws -> URL {
        guard !preferredFilename.isEmpty,
              URL(fileURLWithPath: preferredFilename).lastPathComponent == preferredFilename else {
            throw ExportDirectoryError.invalidFilename
        }

        let filename = preferredFilename as NSString
        let stem = filename.deletingPathExtension
        let pathExtension = filename.pathExtension

        for suffix in 1...10_000 {
            let candidateName: String
            if suffix == 1 {
                candidateName = preferredFilename
            } else if pathExtension.isEmpty {
                candidateName = "\(stem)-\(suffix)"
            } else {
                candidateName = "\(stem)-\(suffix).\(pathExtension)"
            }

            let candidate = directoryURL.appending(
                path: candidateName,
                directoryHint: .notDirectory
            )
            if !fileManager.fileExists(atPath: candidate.path(percentEncoded: false)) {
                return candidate
            }
        }

        throw ExportDirectoryError.tooManyDuplicateFiles
    }
}
