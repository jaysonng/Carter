//
//  URLInformationType.swift
//
//
//  Created by Jayson Ng on 11/24/21.
//  based on Ocarina by Rens Verhoeven
//

import Foundation

public enum URLInformationType: String, Sendable, CaseIterable {
    
    case article                        = "article"
    case book                           = "book"
    case profile                        = "profile"
    case website                        = "website"
    
    case fileImage                      = "file.image"
    case fileVideo                      = "file.video"
    case fileAudio                      = "file.audio"
    case fileDocument                   = "file.document"
    case fileArchive                    = "file.archive"
    case fileOther                      = "file.other"
    
    case music                          = "music"
    case musicSong                      = "music.song"
    case musicPlaylist                  = "music.playlist"
    case musicAlbum                     = "music.album"
    case musicRadioStation              = "music.radio_station"
    
    case videoMovie                     = "video.movie"
    case videoEpisode                   = "video.episode"
    case videoTvShow                    = "video.tv_show"
    case video                          = "video"
    
}


extension URLInformationType {
    
    var isFileURL: Bool {
        return self.rawValue.hasPrefix("file")
    }
    
    static let imageFileMimeTypes: [String] = ["image/bmp",
                                               "image/x-windows-bmp",
                                               "image/gif", "image/jpeg",
                                               "image/pjpeg",
                                               "image/x-icon",
                                               "image/png",
                                               "image/tiff",
                                               "image/x-tiff"]
    
    static let documentFileMimeTypes: [String] = ["application/vnd.ms-powerpoint",
                                                  "application/mspowerpoint",
                                                  "application/mspowerpoint",
                                                  "application/x-mspowerpoint",
                                                  "application/msword",
                                                  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
                                                  "application/vnd.openxmlformats-officedocument.wordprocessingml.template",
                                                  "application/vnd.ms-excel.addin.macroEnabled.12",
                                                  "application/vnd.ms-excel",
                                                  "application/vnd.ms-excel.sheet.binary.macroEnabled.12",
                                                  "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                                                  "application/vnd.openxmlformats-officedocument.spreadsheetml.template",
                                                  "text/plain",
                                                  "application/rtf",
                                                  "application/x-rtf",
                                                  "text/richtext",
                                                  "application/pdf"]
    
    static let htmlFileMimeTypes: [String] =  ["text/html",
                                               "text/x-server-parsed-html"]
    
    static let archiveFileMimeTypes: [String] = ["application/x-compress",
                                                 "application/x-compressed",
                                                 "application/x-zip-compressed",
                                                 "application/zip",
                                                 "multipart/x-zip"]
    
    
    // MARK: ---------------  Helpers  ---------------
    static func type(for typeString: String) -> URLInformationType? {
        if let type = URLInformationType(rawValue: typeString) {
            return type
        }
        switch typeString {
        case "music.other":
            return .music
        case "music.track", "song", "track":
            return .musicSong
        case "playlist":
            return .musicPlaylist
        case "album", "record":
            return .musicAlbum
        case "radio_station", "radio":
            return .musicRadioStation
        case "video.other":
            return .video
        case "movie", "film":
            return .videoMovie
        case "episode":
            return .videoEpisode
        case "tv_show", "tv_series":
            return .videoTvShow
        default:
            return nil
        }
    }
    
    /// Audio and video MIME types, by prefix.
    ///
    /// 1.x asked `AVURLAsset.audiovisualMIMETypes()` for this. That is
    /// AVFoundation — Apple-only — and it is the single reason a link-preview
    /// parser could not compile on a Linux server. The question being asked was
    /// only ever "does this start with audio/ or video/", which needs no
    /// framework and gives the same answer everywhere.
    public static func type(forMimeType mimeType: String) -> URLInformationType {
        let mime = mimeType.lowercased()
            .components(separatedBy: ";").first?
            .trimmingCharacters(in: .whitespaces) ?? mimeType.lowercased()

        if mime.hasPrefix("audio/") { return .fileAudio }
        if mime.hasPrefix("video/") { return .fileVideo }
        if mime.hasPrefix("image/") { return .fileImage }

        if self.imageFileMimeTypes.contains(mime)    { return .fileImage }
        if self.documentFileMimeTypes.contains(mime) { return .fileDocument }
        if self.htmlFileMimeTypes.contains(mime)     { return .website }
        if self.archiveFileMimeTypes.contains(mime)  { return .fileArchive }
        return .fileOther
    }
}
