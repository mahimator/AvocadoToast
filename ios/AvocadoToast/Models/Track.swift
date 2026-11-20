import Foundation

struct Track: Identifiable, Codable, Hashable {
    let videoId: String
    let title: String
    let artist: String
    let album: String?
    let thumbnailURL: URL?
    let duration: String?
    var id: String { videoId }

    enum CodingKeys: String, CodingKey {
        case videoId = "video_id"
        case title, artist, album, duration
        case thumbnailURL = "thumbnail_url"
    }

    static let preview = Track(videoId: "demo-track", title: "Midnight City",
        artist: "M83", album: "Hurry Up, We're Dreaming", thumbnailURL: nil, duration: "4:03")
}