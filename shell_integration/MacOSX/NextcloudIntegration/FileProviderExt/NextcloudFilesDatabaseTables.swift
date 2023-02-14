/*
 * Copyright (C) 2022 by Claudio Cambra <claudio.cambra@nextcloud.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 */

import Foundation
import RealmSwift
import FileProvider
import NextcloudKit

class NextcloudItemMetadataTable: Object {
    enum Status: Int {
        case downloadError = -4
        case downloading = -3
        case inDownload = -2
        case waitDownload = -1

        case normal = 0

        case waitUpload = 1
        case inUpload = 2
        case uploading = 3
        case uploadError = 4
    }

    enum SharePermissions: Int {
        case readShare = 1
        case updateShare = 2
        case createShare = 4
        case deleteShare = 8
        case shareShare = 16

        case maxFileShare = 19
        case maxFolderShare = 31
    }

    override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? NextcloudItemMetadataTable {
            return self.fileId == object.fileId &&
                   self.account == object.account &&
                   self.path == object.path &&
                   self.fileName == object.fileName
        }

        return false
    }

    func isInSameRemoteState(_ comparingMetadata: NextcloudItemMetadataTable) -> Bool {
        return comparingMetadata.etag == self.etag &&
            comparingMetadata.fileNameView == self.fileNameView &&
            comparingMetadata.date == self.date &&
            comparingMetadata.permissions == self.permissions &&
            comparingMetadata.hasPreview == self.hasPreview &&
            comparingMetadata.note == self.note &&
            comparingMetadata.lock == self.lock &&
            comparingMetadata.shareType == self.shareType &&
            comparingMetadata.sharePermissionsCloudMesh == self.sharePermissionsCloudMesh &&
            comparingMetadata.sharePermissionsCollaborationServices == self.sharePermissionsCollaborationServices &&
            comparingMetadata.favorite == self.favorite
    }

    @Persisted(primaryKey: true) var ocId: String
    @Persisted var account = ""
    @Persisted var assetLocalIdentifier = ""
    @Persisted var checksums = ""
    @Persisted var chunk: Bool = false
    @Persisted var classFile = ""
    @Persisted var commentsUnread: Bool = false
    @Persisted var contentType = ""
    @Persisted var creationDate = Date()
    @Persisted var dataFingerprint = ""
    @Persisted var date = Date()
    @Persisted var directory: Bool = false
    @Persisted var deleteAssetLocalIdentifier: Bool = false
    @Persisted var downloadURL = ""
    @Persisted var e2eEncrypted: Bool = false
    @Persisted var edited: Bool = false
    @Persisted var etag = ""
    @Persisted var etagResource = ""
    @Persisted var favorite: Bool = false
    @Persisted var fileId = ""
    @Persisted var fileName = ""
    @Persisted var fileNameView = ""
    @Persisted var hasPreview: Bool = false
    @Persisted var iconName = ""
    @Persisted var iconUrl = ""
    @Persisted var isExtractFile: Bool = false
    @Persisted var livePhoto: Bool = false
    @Persisted var mountType = ""
    @Persisted var name = "" // for unifiedSearch is the provider.id
    @Persisted var note = ""
    @Persisted var ownerId = ""
    @Persisted var ownerDisplayName = ""
    @Persisted var lock = false
    @Persisted var lockOwner = ""
    @Persisted var lockOwnerEditor = ""
    @Persisted var lockOwnerType = 0
    @Persisted var lockOwnerDisplayName = ""
    @Persisted var lockTime: Date?
    @Persisted var lockTimeOut: Date?
    @Persisted var path = ""
    @Persisted var permissions = ""
    @Persisted var quotaUsedBytes: Int64 = 0
    @Persisted var quotaAvailableBytes: Int64 = 0
    @Persisted var resourceType = ""
    @Persisted var richWorkspace: String?
    @Persisted var serverUrl = "" // For parent directory!!
    @Persisted var session = ""
    @Persisted var sessionError = ""
    @Persisted var sessionSelector = ""
    @Persisted var sessionTaskIdentifier: Int = 0
    @Persisted var sharePermissionsCollaborationServices: Int = 0
    let sharePermissionsCloudMesh = List<String>()
    let shareType = List<Int>()
    @Persisted var size: Int64 = 0
    @Persisted var status: Int = 0
    @Persisted var subline: String?
    @Persisted var trashbinFileName = ""
    @Persisted var trashbinOriginalLocation = ""
    @Persisted var trashbinDeletionTime = Date()
    @Persisted var uploadDate = Date()
    @Persisted var url = ""
    @Persisted var urlBase = ""
    @Persisted var user = ""
    @Persisted var userId = ""

    var fileExtension: String {
        (fileNameView as NSString).pathExtension
    }

    var fileNoExtension: String {
        (fileNameView as NSString).deletingPathExtension
    }

    var isRenameable: Bool {
        return lock
    }

    var isPrintable: Bool {
        if isDocumentViewableOnly {
            return false
        }
        if ["application/pdf", "com.adobe.pdf"].contains(contentType) || contentType.hasPrefix("text/") || classFile == NKCommon.typeClassFile.image.rawValue {
            return true
        }
        return false
    }

    var isDocumentViewableOnly: Bool {
        return sharePermissionsCollaborationServices == SharePermissions.readShare.rawValue &&
            classFile == NKCommon.typeClassFile.document.rawValue
    }

    var isCopyableInPasteboard: Bool {
        !isDocumentViewableOnly && !directory
    }

    var isModifiableWithQuickLook: Bool {
        if directory || isDocumentViewableOnly {
            return false
        }
        return contentType == "com.adobe.pdf" || contentType == "application/pdf" || classFile == NKCommon.typeClassFile.image.rawValue
    }

    var isSettableOnOffline: Bool {
        return session.isEmpty && !isDocumentViewableOnly
    }

    var canOpenIn: Bool {
        return session.isEmpty && !isDocumentViewableOnly && !directory
    }

    var isDownloadUpload: Bool {
        return status == Status.inDownload.rawValue ||
            status == Status.downloading.rawValue ||
            status == Status.inUpload.rawValue ||
            status == Status.uploading.rawValue
    }

    var isDownload: Bool {
        status == Status.inDownload.rawValue || status == Status.downloading.rawValue
    }

    var isUpload: Bool {
        status == Status.inUpload.rawValue || status == Status.uploading.rawValue
    }

    /// Returns false if the user is lokced out of the file. I.e. The file is locked but by somone else
    func canUnlock(as user: String) -> Bool {
        return !lock || (lockOwner == user && lockOwnerType == 0)
    }
}

class NextcloudDirectoryMetadataTable: Object {
    func isInSameRemoteState(_ comparingMetadata: NextcloudDirectoryMetadataTable) -> Bool {
        return comparingMetadata.etag == self.etag &&
            comparingMetadata.e2eEncrypted == self.e2eEncrypted &&
            comparingMetadata.favorite == self.favorite &&
            comparingMetadata.permissions == self.permissions
    }

    @Persisted(primaryKey: true) var ocId: String
    @Persisted var account = ""
    @Persisted var colorFolder: String?
    @Persisted var e2eEncrypted: Bool = false
    @Persisted var etag = ""
    @Persisted var favorite: Bool = false
    @Persisted var fileId = ""
    @Persisted var offline: Bool = false
    @Persisted var permissions = ""
    @Persisted var richWorkspace: String?
    @Persisted var serverUrl = ""
    @Persisted var parentDirectoryServerUrl = ""
}

class NextcloudLocalFileMetadataTable: Object {
    @Persisted(primaryKey: true) var ocId: String
    @Persisted var account = ""
    @Persisted var etag = ""
    @Persisted var exifDate: Date?
    @Persisted var exifLatitude = ""
    @Persisted var exifLongitude = ""
    @Persisted var exifLensModel: String?
    @Persisted var favorite: Bool = false
    @Persisted var fileName = ""
    @Persisted var offline: Bool = false
}
