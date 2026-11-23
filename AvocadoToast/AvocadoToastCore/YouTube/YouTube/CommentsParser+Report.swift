//
//  CommentsParser+Report.swift
//  SwiftyTube
//
//  Created by 686udjie on 14/11/2026.
//

extension CommentsParser {

    static func reportParams(in surface: [String: Any]?, entity: [String: Any]) -> String? {
        if let surface,
           let items = dictionary(surface, "menuCommand", "innertubeCommand", "menuEndpoint", "menu", "menuRenderer")?["items"]
            as? [[String: Any]],
           let params = reportToken(in: items) {
            return params
        }
        for key in ["actionMenu", "menu"] {
            guard let items = dictionary(entity, key, "menuRenderer")?["items"] as? [[String: Any]] else { continue }
            if let params = reportToken(in: items) { return params }
        }
        return nil
    }

    /// The Report menu item is a `showEngagementPanelEndpoint` for the
    /// abuse-report panel (`PAabuse_report`, FLAG icon) whose
    /// `globalConfiguration.params` seeds `get_panel`.
    private static func reportToken(in items: [[String: Any]]) -> String? {
        for item in items {
            guard let renderer = item["menuServiceItemRenderer"] as? [String: Any]
                    ?? item["menuNavigationItemRenderer"] as? [String: Any],
                  let endpoint = renderer["serviceEndpoint"] as? [String: Any]
                    ?? renderer["navigationEndpoint"] as? [String: Any],
                  let panel = endpoint["showEngagementPanelEndpoint"] as? [String: Any],
                  let config = panel["globalConfiguration"] as? [String: Any],
                  let params = config["params"] as? String
            else { continue }
            let tag = dictionary(panel, "identifier")?["tag"] as? String
            let icon = dictionary(renderer, "icon")?["iconType"] as? String
            if tag == "PAabuse_report" || icon == "FLAG" { return params }
        }
        return nil
    }

    // MARK: - Report flow

    /// One reason on the abuse-report reason-select page.
    public struct CommentReportReason {
        /// Server key sent back as `abuseReportFlowState.reasonKey`
        /// (`SEXUAL`, `SPAM`, …).
        public var key: String
        /// Server-localized label; nil only if YouTube omits it.
        public var text: String?
        /// The radio item's full command (`{innertubeCommand: …}`); replayed
        /// as `abuseReportFlowState.navigationCommand` when advancing.
        public var command: [String: Any]
    }

    /// Parsed `get_panel` response: the reason page plus the flow-state
    /// entity that every later `/flow` call must echo back.
    public struct CommentReportPanel {
        public var title: String?
        public var pageHeader: String?
        public var bodyText: String?
        public var emptyReasonMessage: String?
        /// Bottom-bar primary button title (server-localized).
        public var navTitle: String?
        public var reasons: [CommentReportReason]
        public var flowState: [String: Any]
        public var flowStateEntityKey: String
        public var flowId: String
        public var targetId: String
    }

    /// The optional-details step (`reportFormDetailsPageViewModel`).
    public struct CommentReportDetailsPage {
        public var header: String?
        public var bodyText: String?
        public var placeholder: String?
        public var maxChars: Int
        public var maxCharsErrorMessage: String?
    }

    /// The success step (`reportFormConfirmationPageViewModel`).
    public struct CommentReportConfirmationPage {
        public struct NextStep {
            public var iconName: String?
            public var text: String?
        }

        public var header: String?
        public var text: String?
        public var lawEnforcementText: String?
        public var whatToExpectHeader: String?
        public var nextSteps: [NextStep]
        public var legalReportText: String?
    }

    /// A classified `flowStepRenderer` from an `/flow` response.
    public struct CommentReportStep {
        public enum Page {
            case reasons(header: String?, body: String?, reasons: [CommentReportReason])
            case details(CommentReportDetailsPage)
            case confirmation(CommentReportConfirmationPage)
            case signIn(header: String?, text: String?)
            case unknown
        }

        public var stepId: String?
        public var page: Page
        /// Bottom-bar primary button title (server-localized).
        public var navTitle: String?
        public var hasCancelButton: Bool
        public var flowStateKey: String?
    }

    /// Result of one `/flow` advance.
    public struct CommentReportFlowUpdate {
        public enum Outcome {
            /// Server advanced: `flowStepRenderer` bodies (already unwrapped
            /// from their `{flowStepRenderer: …}` wrappers) to classify.
            case steps([[String: Any]])
            /// Server rejected the state — carries its toast text, if any.
            case failure(String?)
            /// 200 with no `updateFlowCommand`: our state was a no-op.
            case noOp
        }

        public var outcome: Outcome
        /// Replacement entity from `entityUpdateCommand`, when present.
        public var flowState: [String: Any]?
        public var flowStateEntityKey: String?
        public var flowContinuationCommand: [String: Any]?
    }

    /// Reads the reason-select step out of a `get_panel` response.
    public static func parseReportPanel(_ json: [String: Any]) -> CommentReportPanel? {
        guard let step = firstFlowStep(in: json),
              let reasonPage = dictionary(step, "content", "reportFormReasonSelectPageViewModel"),
              let entity = flowStateEntity(in: json) else { return nil }

        let reasons = reportReasons(from: reasonPage)
        let route = flowRoute(from: reasons.first?.command)
        let entityKey = entity["key"] as? String
            ?? getFlowField(in: reasons.first?.command, key: "flowStateEntityKey")
            ?? ""
        guard !entityKey.isEmpty else { return nil }

        let bottomBar = dictionary(step, "bottomBar", "reportFormBottomBarViewModel")
        return CommentReportPanel(
            title: flowTopBarTitle(in: step),
            pageHeader: reportText(reasonPage["pageHeader"]),
            bodyText: reportText(reasonPage["bodyText"]),
            emptyReasonMessage: reportText(reasonPage["emptyReasonSelectErrorMessage"]),
            navTitle: reportText(dictionary(bottomBar ?? [:], "navButton", "buttonViewModel")?["title"]),
            reasons: reasons,
            flowState: entity,
            flowStateEntityKey: entityKey,
            flowId: route.flowId,
            targetId: route.targetId
        )
    }

    /// Classifies a single `flowStepRenderer`.
    public static func parseReportStep(_ step: [String: Any]) -> CommentReportStep {
        let content = step["content"] as? [String: Any] ?? [:]
        let bottomBar = dictionary(step, "bottomBar", "reportFormBottomBarViewModel")
        let navTitle = reportText(dictionary(bottomBar ?? [:], "navButton", "buttonViewModel")?["title"])
        let hasCancel = bottomBar?["cancelButton"] != nil

        if let page = content["reportFormDetailsPageViewModel"] as? [String: Any] {
            let inputBox = dictionary(page, "inputBox", "inputBoxViewModel")
            let maxChars = (inputBox?["maxChars"] as? Int)
                ?? (inputBox?["maxChars"] as? String).flatMap(Int.init)
                ?? 500
            return CommentReportStep(
                stepId: step["stepId"] as? String,
                page: .details(CommentReportDetailsPage(
                    header: reportText(page["detailsPageHeader"]),
                    bodyText: reportText(page["bodyText"]),
                    placeholder: reportText(inputBox?["placeholderText"]),
                    maxChars: maxChars,
                    maxCharsErrorMessage: reportText(inputBox?["maxCharsExceededErrorMessage"])
                )),
                navTitle: navTitle,
                hasCancelButton: hasCancel,
                flowStateKey: flowStateKey(of: page) ?? (bottomBar?["flowStateKey"] as? String)
            )
        }

        if let page = content["reportFormConfirmationPageViewModel"] as? [String: Any] {
            let nextSteps = (page["nextSteps"] as? [[String: Any]] ?? []).map {
                CommentReportConfirmationPage.NextStep(
                    iconName: $0["iconName"] as? String,
                    text: reportText($0["text"])
                )
            }
            return CommentReportStep(
                stepId: step["stepId"] as? String,
                page: .confirmation(CommentReportConfirmationPage(
                    header: reportText(page["confirmationHeader"]),
                    text: reportText(page["confirmationText"]),
                    lawEnforcementText: reportText(page["lawEnforcementText"]),
                    whatToExpectHeader: reportText(page["whatToExpectHeader"]),
                    nextSteps: nextSteps,
                    legalReportText: reportText(page["legalReportText"])
                )),
                navTitle: navTitle,
                hasCancelButton: hasCancel,
                flowStateKey: flowStateKey(of: page) ?? (bottomBar?["flowStateKey"] as? String)
            )
        }

        if let page = content["reportFormSignInPageViewModel"] as? [String: Any] {
            return CommentReportStep(
                stepId: step["stepId"] as? String,
                page: .signIn(
                    header: reportText(page["header"]),
                    text: reportText(page["text"])
                ),
                navTitle: navTitle,
                hasCancelButton: hasCancel,
                flowStateKey: flowStateKey(of: page) ?? (bottomBar?["flowStateKey"] as? String)
            )
        }

        if let page = content["reportFormReasonSelectPageViewModel"] as? [String: Any] {
            return CommentReportStep(
                stepId: step["stepId"] as? String,
                page: .reasons(
                    header: reportText(page["pageHeader"]),
                    body: reportText(page["bodyText"]),
                    reasons: reportReasons(from: page)
                ),
                navTitle: navTitle,
                hasCancelButton: hasCancel,
                flowStateKey: flowStateKey(of: page) ?? (bottomBar?["flowStateKey"] as? String)
            )
        }

        return CommentReportStep(
            stepId: step["stepId"] as? String,
            page: .unknown,
            navTitle: navTitle,
            hasCancelButton: hasCancel,
            flowStateKey: bottomBar?["flowStateKey"] as? String
        )
    }

    /// Interprets an `/flow` response body. The client executes commands
    /// recursively, so the success payload does *not* carry `steps` at the
    /// top level: on success YouTube nests them inside
    /// `commandExecutorCommand.commands[*].updateFlowCommand` next to a
    /// double-wrapped `entityUpdateCommand` (and `hideReportedCommentAction`);
    /// on rejection the same slot holds a toast `openPopupAction`.
    public static func parseReportFlowUpdate(_ json: [String: Any]) -> CommentReportFlowUpdate {
        guard let update = json["updateFlowCommand"] as? [String: Any] else {
            return CommentReportFlowUpdate(
                outcome: .noOp,
                flowState: nil,
                flowStateEntityKey: nil,
                flowContinuationCommand: nil
            )
        }

        var parts = ReportFlowUpdateParts()
        walkReportUpdate(update, into: &parts)

        if !parts.steps.isEmpty {
            return CommentReportFlowUpdate(
                outcome: .steps(parts.steps),
                flowState: parts.flowState,
                flowStateEntityKey: parts.flowStateEntityKey,
                flowContinuationCommand: parts.flowContinuationCommand
            )
        }
        if let toast = parts.toast {
            return CommentReportFlowUpdate(
                outcome: .failure(toast),
                flowState: parts.flowState,
                flowStateEntityKey: parts.flowStateEntityKey,
                flowContinuationCommand: nil
            )
        }
        if parts.sawCommand {
            // Commands ran but produced neither steps nor a toast — treat as
            // a rejection so the sheet surfaces its own error instead of
            // silently doing nothing.
            return CommentReportFlowUpdate(
                outcome: .failure(nil),
                flowState: parts.flowState,
                flowStateEntityKey: parts.flowStateEntityKey,
                flowContinuationCommand: nil
            )
        }
        return CommentReportFlowUpdate(
            outcome: .noOp,
            flowState: nil,
            flowStateEntityKey: nil,
            flowContinuationCommand: nil
        )
    }

    /// One pass over an `updateFlowCommand` command tree.
    private struct ReportFlowUpdateParts {
        var steps: [[String: Any]] = []
        var flowState: [String: Any]?
        var flowStateEntityKey: String?
        var flowContinuationCommand: [String: Any]?
        var toast: String?
        var sawCommand = false
    }

    private static func walkReportUpdate(_ node: [String: Any], into parts: inout ReportFlowUpdateParts) {
        if parts.steps.isEmpty,
           let raw = node["steps"] as? [[String: Any]], !raw.isEmpty {
            // Elements arrive as `{flowStepRenderer: …}` wrappers (same as
            // the panel response); unwrap so callers classify step bodies.
            parts.steps = raw.map { $0["flowStepRenderer"] as? [String: Any] ?? $0 }
        }
        if let batch = node["entityBatchUpdate"] as? [String: Any] {
            applyFlowStateBatch(batch, into: &parts)
        }
        if let entityUpdate = node["entityUpdateCommand"] as? [String: Any] {
            walkReportUpdate(entityUpdate, into: &parts)
        }
        if parts.flowContinuationCommand == nil,
           let continuation = node["flowContinuationCommand"] as? [String: Any] {
            parts.flowContinuationCommand = continuation
        }
        if parts.toast == nil,
           let popup = node["openPopupAction"] as? [String: Any],
           let renderer = dictionary(popup, "popup", "notificationActionRenderer") {
            parts.toast = reportText(renderer["responseText"])
        }
        if let inner = node["updateFlowCommand"] as? [String: Any] {
            walkReportUpdate(inner, into: &parts)
        }
        if let executor = node["commandExecutorCommand"] as? [String: Any],
           let commands = executor["commands"] as? [[String: Any]] {
            parts.sawCommand = true
            for command in commands {
                walkReportUpdate(command, into: &parts)
            }
        }
    }

    private static func applyFlowStateBatch(_ batch: [String: Any], into parts: inout ReportFlowUpdateParts) {
        guard let mutations = batch["mutations"] as? [[String: Any]] else { return }
        for mutation in mutations {
            guard let payload = mutation["payload"] as? [String: Any],
                  let entity = payload["flowStateEntity"] as? [String: Any] else { continue }
            parts.flowState = entity
            parts.flowStateEntityKey = (entity["key"] as? String)
                ?? (mutation["entityKey"] as? String)
                ?? parts.flowStateEntityKey
        }
    }

    /// `flowId`/`targetId` embedded in a radio command's `getFlowCommand`.
    public static func flowRoute(from command: [String: Any]?) -> (flowId: String, targetId: String) {
        (
            getFlowField(in: command, key: "flowId") ?? "abuse_report_flow",
            getFlowField(in: command, key: "targetId") ?? "abuse_report_flow"
        )
    }

    /// Tolerant text extraction: plain string, `{content}`, `{simpleText}`,
    /// or `{runs: [{text}]}` (all shapes YouTube uses for flow copy).
    public static func reportText(_ node: Any?) -> String? {
        if let string = node as? String { return string }
        guard let dict = node as? [String: Any] else { return nil }
        if let string = dict["content"] as? String { return string }
        if let string = dict["simpleText"] as? String { return string }
        if let runs = dict["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private static func firstFlowStep(in json: [String: Any]) -> [String: Any]? {
        guard let panel = dictionary(json, "content", "engagementPanelSectionListRenderer", "content", "flowRootRenderer"),
              let steps = panel["steps"] as? [[String: Any]],
              let first = steps.first else { return nil }
        return first["flowStepRenderer"] as? [String: Any]
    }

    private static func flowStateEntity(in json: [String: Any]) -> [String: Any]? {
        guard let mutations = dictionary(json, "frameworkUpdates", "entityBatchUpdate")?["mutations"]
            as? [[String: Any]] else { return nil }
        for mutation in mutations {
            guard let payload = mutation["payload"] as? [String: Any],
                  let entity = payload["flowStateEntity"] as? [String: Any] else { continue }
            return entity
        }
        return nil
    }

    private static func reportReasons(from page: [String: Any]) -> [CommentReportReason] {
        guard let group = dictionary(page, "radioButtonGroup", "radioButtonGroupViewModel"),
              let buttons = group["radioButtons"] as? [[String: Any]] else { return [] }
        return buttons.compactMap { button in
            guard let vm = button["radioButtonItemViewModel"] as? [String: Any],
                  let key = vm["key"] as? String else { return nil }
            return CommentReportReason(
                key: key,
                text: reportText(vm["text"]),
                command: (vm["command"] as? [String: Any]) ?? [:]
            )
        }
    }

    private static func flowTopBarTitle(in step: [String: Any]) -> String? {
        reportText(dictionary(step, "topBarOverride", "flowTopBarRenderer")?["title"])
    }

    private static func flowStateKey(of page: [String: Any]) -> String? {
        page["flowStateKey"] as? String
    }

    private static func getFlowField(in command: [String: Any]?, key: String) -> String? {
        guard let command else { return nil }
        let inner = command["innertubeCommand"] as? [String: Any] ?? command
        return (inner["getFlowCommand"] as? [String: Any])?[key] as? String
    }
}
