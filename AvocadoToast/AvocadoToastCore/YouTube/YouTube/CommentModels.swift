//
//  CommentModels.swift
//  SwiftyTube
//
//  Created by 686udjie on 12/11/2026.
//

import Foundation

/// Sort order for a YouTube comments section.
public enum CommentSort: String, CaseIterable, Identifiable, Sendable {
    case top
    case newest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .top: return "Top"
        case .newest: return "Newest"
        }
    }
}

/// A run of text inside a comment body.
public enum CommentTextRun: Hashable, Sendable {
    case text(String)
    case link(text: String, url: URL)
    case timestamp(text: String, seconds: Double, videoId: String?)
}

public struct CommentAuthor: Hashable, Sendable {
    public var name: String
    public var avatarURL: String?
    public var channelURL: String?
    public var isCreator: Bool
    public var isVerified: Bool
    public var isArtist: Bool
}

public enum CommentVoteState: String, Hashable, Sendable {
    case indifferent
    case liked
    case disliked
}

public struct CommentItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var author: CommentAuthor
    public var runs: [CommentTextRun]
    public var publishedTime: String
    public var likeCountText: String
    public var isHearted: Bool
    public var isPinned: Bool
    public var pinnedText: String?
    public var replyCount: Int
    public var replyCountText: String
    public var replyContinuation: String?
    /// Viewer's current vote. Only meaningful together with the action tokens.
    public var voteState: CommentVoteState = .indifferent
    /// Server-issued `performCommentActionEndpoint` tokens for the viewer's
    /// toolbar surface. All nil when signed out — the viewer must sign in
    /// before any vote can be performed.
    public var likeAction: String?
    public var unlikeAction: String?
    public var dislikeAction: String?
    public var undislikeAction: String?
    public var deleteAction: String?
    public var editParams: String?
    /// Server-issued `showEngagementPanelEndpoint.globalConfiguration.params`
    /// for the comment's Report menu item (`PAabuse_report`). Nil when signed
    /// out — YouTube only ships the menu on signed-in comment payloads.
    public var reportParams: String?
}

public struct CommentsPage: Sendable {
    public var items: [CommentItem]
    public var nextPageToken: String?
    public var sortTokens: [CommentSort: String]
    public var totalCountText: String?
    public var createCommentParams: String?
}

public struct CommentRepliesPage: Sendable {
    public var items: [CommentItem]
    public var nextPageToken: String?
}
