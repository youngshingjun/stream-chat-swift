//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

public typealias ChatMessageContentView = _ChatMessageContentView<NoExtraData>

open class _ChatMessageContentView<ExtraData: ExtraDataTypes>: _View, UIConfigProvider {
    public var message: _ChatMessageGroupPart<ExtraData>? {
        didSet { updateContentIfNeeded() }
    }

    public var onThreadTap: (_ChatMessageGroupPart<ExtraData>?) -> Void = { _ in }
    public var onErrorIndicatorTap: (_ChatMessageGroupPart<ExtraData>?) -> Void = { _ in }
    public var onLinkTap: (ChatMessageDefaultAttachment?) -> Void = { _ in } {
        didSet { updateContentIfNeeded() }
    }

    // MARK: - Subviews

    public private(set) lazy var messageBubbleView = uiConfig
        .messageList
        .messageContentSubviews
        .bubbleView.init()
        .withoutAutoresizingMaskConstraints
    
    // --
    public private(set) lazy var textView: UITextView = {
        let textView = OnlyLinkTappableTextView()
        textView.isEditable = false
        textView.dataDetectorTypes = .link
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.font = uiConfig.font.body
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        return textView.withoutAutoresizingMaskConstraints
    }()
    
    public private(set) lazy var linkPreviewView = uiConfig
        .messageList
        .messageContentSubviews
        .linkPreviewView
        .init()
        .withoutAutoresizingMaskConstraints
    
    public private(set) lazy var quotedMessageView = uiConfig
        .messageList
        .messageContentSubviews
        .quotedMessageBubbleView.init()
        .withoutAutoresizingMaskConstraints
    
    public private(set) lazy var attachmentsView = uiConfig
        .messageList
        .messageContentSubviews
        .attachmentSubviews
        .attachmentsView
        .init()
        .withoutAutoresizingMaskConstraints
    // --

    public private(set) lazy var messageMetadataView = uiConfig
        .messageList
        .messageContentSubviews
        .metadataView
        .init()
        .withoutAutoresizingMaskConstraints
    
    public private(set) lazy var authorAvatarView = uiConfig
        .messageList
        .messageContentSubviews
        .authorAvatarView
        .init()
        .withoutAutoresizingMaskConstraints

    public private(set) lazy var reactionsBubble = uiConfig
        .messageList
        .messageReactions
        .reactionsBubbleView
        .init()
        .withoutAutoresizingMaskConstraints

    public private(set) lazy var threadArrowView = uiConfig
        .messageList
        .messageContentSubviews
        .threadArrowView
        .init()
        .withoutAutoresizingMaskConstraints

    public private(set) lazy var threadView = uiConfig
        .messageList
        .messageContentSubviews
        .threadInfoView
        .init()
        .withoutAutoresizingMaskConstraints

    public private(set) lazy var errorIndicator = uiConfig
        .messageList
        .messageContentSubviews
        .errorIndicator
        .init()
        .withoutAutoresizingMaskConstraints

    var incomingMessageConstraints: [NSLayoutConstraint] = []
    var outgoingMessageConstraints: [NSLayoutConstraint] = []
    var bubbleToReactionsConstraint: NSLayoutConstraint?
    var bubbleToMetadataConstraint: NSLayoutConstraint?
    var bubbleToErrorIndicatorConstraint: NSLayoutConstraint?

    var incomingMessageIsThreadConstraints: [NSLayoutConstraint] = []
    var outgoingMessageIsThreadConstraints: [NSLayoutConstraint] = []
    
    public fileprivate(set) var layoutConstraints: [ChatMessageContentViewLayoutOptions: [NSLayoutConstraint]] = [:]

    // MARK: - Overrides

    override open func setUp() {
        super.setUp()

        reactionsBubble.isUserInteractionEnabled = false
        threadView.addTarget(self, action: #selector(didTapOnThread), for: .touchUpInside)
        errorIndicator.addTarget(self, action: #selector(didTapOnErrorIndicator), for: .touchUpInside)
        linkPreviewView.addTarget(self, action: #selector(didTapOnLinkPreview), for: .touchUpInside)
    }

    override open func setUpLayout() {
        addSubview(messageBubbleView)
        addSubview(messageMetadataView)
        addSubview(authorAvatarView)
        addSubview(reactionsBubble)
        addSubview(threadArrowView)
        addSubview(threadView)
        addSubview(errorIndicator)

        errorIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)
        errorIndicator.setContentCompressionResistancePriority(.required, for: .vertical)

        incomingMessageIsThreadConstraints = [
            threadView.bottomAnchor.pin(equalTo: bottomAnchor),
            messageMetadataView.leadingAnchor.pin(equalToSystemSpacingAfter: threadView.trailingAnchor, multiplier: 1)
        ]

        outgoingMessageIsThreadConstraints = [
            threadView.bottomAnchor.pin(equalTo: bottomAnchor),
            threadView.leadingAnchor.pin(equalToSystemSpacingAfter: messageMetadataView.trailingAnchor, multiplier: 1)
        ]

        NSLayoutConstraint.activate([
            authorAvatarView.widthAnchor.pin(equalToConstant: 32),
            authorAvatarView.heightAnchor.pin(equalToConstant: 32),
            authorAvatarView.leadingAnchor.pin(equalTo: leadingAnchor),
            authorAvatarView.bottomAnchor.pin(equalTo: bottomAnchor),
            
            reactionsBubble.topAnchor.pin(equalTo: topAnchor),
            
            messageBubbleView.trailingAnchor.pin(equalTo: trailingAnchor).almostRequired,
            messageBubbleView.topAnchor.pin(equalTo: topAnchor).with(priority: .defaultHigh),
            messageBubbleView.bottomAnchor.pin(equalTo: bottomAnchor).with(priority: .defaultHigh),
            
            messageMetadataView.heightAnchor.pin(equalToConstant: 16),
            messageMetadataView.bottomAnchor.pin(equalTo: bottomAnchor),
            
            threadArrowView.widthAnchor.pin(equalToConstant: 16),
            threadArrowView.topAnchor.pin(equalTo: messageBubbleView.centerYAnchor),
            threadArrowView.bottomAnchor.pin(equalTo: threadView.centerYAnchor),
            
            threadView.topAnchor.pin(equalToSystemSpacingBelow: messageBubbleView.bottomAnchor, multiplier: 1),
            
            errorIndicator.bottomAnchor.pin(equalTo: messageBubbleView.bottomAnchor),
            errorIndicator.trailingAnchor.pin(equalTo: trailingAnchor)
        ])

        // this one is ugly: reactions view is part of message content, but is not part of it frame horizontally.
        // In same time we want to prevent reactions view to slip out of screen / cell.
        // We maybe should rethink layout of content view and make reactions part of frame horizontally as well.
        // This will solve superview access hack
        if let superview = self.superview {
            reactionsBubble.trailingAnchor.pin(lessThanOrEqualTo: superview.trailingAnchor).isActive = true
            reactionsBubble.leadingAnchor.pin(greaterThanOrEqualTo: superview.leadingAnchor).isActive = true
        }

        incomingMessageConstraints = [
            reactionsBubble.centerXAnchor.pin(equalTo: messageBubbleView.trailingAnchor, constant: 8),
            reactionsBubble.tailLeadingAnchor.pin(equalTo: messageBubbleView.trailingAnchor, constant: -5),
            
            messageMetadataView.leadingAnchor.pin(equalTo: messageBubbleView.leadingAnchor).with(priority: .defaultHigh),
            messageBubbleView.leadingAnchor.pin(
                equalToSystemSpacingAfter: authorAvatarView.trailingAnchor,
                multiplier: 1
            ),
            threadArrowView.leadingAnchor.pin(equalTo: messageBubbleView.leadingAnchor),
            threadView.leadingAnchor.pin(equalTo: threadArrowView.trailingAnchor)
        ]

        outgoingMessageConstraints = [
            reactionsBubble.centerXAnchor.pin(equalTo: messageBubbleView.leadingAnchor, constant: -8),
            reactionsBubble.tailTrailingAnchor.pin(equalTo: messageBubbleView.leadingAnchor, constant: 5),
            
            messageMetadataView.trailingAnchor.pin(equalTo: messageBubbleView.trailingAnchor).with(priority: .defaultHigh),
            messageBubbleView.leadingAnchor.pin(equalTo: leadingAnchor),
            threadArrowView.trailingAnchor.pin(equalTo: messageBubbleView.trailingAnchor),
            threadView.trailingAnchor.pin(equalTo: threadArrowView.leadingAnchor)
        ]

        bubbleToReactionsConstraint = messageBubbleView.topAnchor.pin(
            equalTo: reactionsBubble.centerYAnchor
        )
        bubbleToMetadataConstraint = messageMetadataView.topAnchor.pin(
            equalToSystemSpacingBelow: messageBubbleView.bottomAnchor,
            multiplier: 1
        )
        bubbleToErrorIndicatorConstraint = messageBubbleView.trailingAnchor.pin(
            equalTo: errorIndicator.centerXAnchor
        )
        
        // --
        addSubview(quotedMessageView)
        addSubview(linkPreviewView)
        addSubview(textView)
        
        // We add `attachmentsView` as a subview to `bubbleView`
        // so it's corners are properly masked
        messageBubbleView.addSubview(attachmentsView)
        
        // Visibility of these views are controlled in their respective `update` methods
        quotedMessageView.isVisible = false
        linkPreviewView.isVisible = false
        attachmentsView.isVisible = false
        
        layoutConstraints[.attachments] = [
            attachmentsView.leadingAnchor.pin(equalTo: messageBubbleView.leadingAnchor),
            attachmentsView.trailingAnchor.pin(equalTo: messageBubbleView.trailingAnchor),
            attachmentsView.topAnchor.pin(equalTo: messageBubbleView.topAnchor),
            attachmentsView.bottomAnchor.pin(equalTo: messageBubbleView.bottomAnchor),
            attachmentsView.widthAnchor.pin(equalToConstant: UIScreen.main.bounds.width * 0.6)
        ]
        
        layoutConstraints[[.text, .attachments]] = [
            attachmentsView.leadingAnchor.pin(equalTo: messageBubbleView.leadingAnchor),
            attachmentsView.trailingAnchor.pin(equalTo: messageBubbleView.trailingAnchor),
            attachmentsView.topAnchor.pin(equalTo: messageBubbleView.topAnchor),
            attachmentsView.widthAnchor.pin(equalToConstant: UIScreen.main.bounds.width * 0.6),
            
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.pin(equalToSystemSpacingBelow: attachmentsView.bottomAnchor, multiplier: 1),
            textView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor)
        ]
        
        layoutConstraints[[.attachments, .quotedMessage]] = [
            quotedMessageView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            quotedMessageView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            quotedMessageView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            
            attachmentsView.leadingAnchor.pin(equalTo: messageBubbleView.leadingAnchor),
            attachmentsView.trailingAnchor.pin(equalTo: messageBubbleView.trailingAnchor),
            attachmentsView.topAnchor.pin(equalToSystemSpacingBelow: quotedMessageView.bottomAnchor, multiplier: 1),
            attachmentsView.widthAnchor.pin(equalToConstant: UIScreen.main.bounds.width * 0.6),
            attachmentsView.bottomAnchor.pin(equalTo: messageBubbleView.bottomAnchor)
        ]
        
        layoutConstraints[[.text, .attachments, .quotedMessage]] = [
            quotedMessageView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            quotedMessageView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            quotedMessageView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            
            attachmentsView.leadingAnchor.pin(equalTo: messageBubbleView.leadingAnchor),
            attachmentsView.trailingAnchor.pin(equalTo: messageBubbleView.trailingAnchor),
            attachmentsView.topAnchor.pin(equalToSystemSpacingBelow: quotedMessageView.bottomAnchor, multiplier: 1),
            attachmentsView.widthAnchor.pin(equalToConstant: UIScreen.main.bounds.width * 0.6),
            
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.pin(equalToSystemSpacingBelow: attachmentsView.bottomAnchor, multiplier: 1),
            textView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor)
        ]
        
        layoutConstraints[.text] = [
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor)
        ]
        
        // link preview cannot exist without text, we can skip `[.linkPreview]` case
        
        layoutConstraints[.quotedMessage] = [
            quotedMessageView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            quotedMessageView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            quotedMessageView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            quotedMessageView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor)
        ]
        
        layoutConstraints[[.text, .linkPreview]] = [
            textView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            
            linkPreviewView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            linkPreviewView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            linkPreviewView.topAnchor.pin(equalToSystemSpacingBelow: textView.bottomAnchor, multiplier: 1),
            linkPreviewView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor),
            linkPreviewView.widthAnchor.pin(equalToConstant: UIScreen.main.bounds.width * 0.6)
        ]
        
        layoutConstraints[[.text, .quotedMessage]] = [
            quotedMessageView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            quotedMessageView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            quotedMessageView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.pin(equalToSystemSpacingBelow: quotedMessageView.bottomAnchor, multiplier: 1),
            textView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor)
        ]
        
        layoutConstraints[[.text, .quotedMessage, .linkPreview]] = [
            quotedMessageView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            quotedMessageView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            quotedMessageView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.pin(equalToSystemSpacingBelow: quotedMessageView.bottomAnchor, multiplier: 1),
            
            linkPreviewView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            linkPreviewView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            linkPreviewView.topAnchor.pin(equalToSystemSpacingBelow: textView.bottomAnchor, multiplier: 1),
            linkPreviewView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor),
            linkPreviewView.widthAnchor.pin(equalToConstant: UIScreen.main.bounds.width * 0.6)
        ]
        
        // link preview is not visible when any attachment presented,
        // so we can skip `[.text, .attachments, .inlineReply, .linkPreview]` case
        // --
    }

    // MARK: wip

    open func removeAllDynamicConstraints() {
        constraintsToDeactivate += outgoingMessageConstraints
        constraintsToDeactivate += incomingMessageConstraints
        constraintsToDeactivate += outgoingMessageIsThreadConstraints
        constraintsToDeactivate += incomingMessageIsThreadConstraints

        constraintsToDeactivate += [
            bubbleToReactionsConstraint,
            bubbleToErrorIndicatorConstraint,
            bubbleToMetadataConstraint
        ].compactMap { $0 }

        setNeedsUpdateConstraints()
    }

    public var constraintsToActivate: [NSLayoutConstraint] = []
    public var constraintsToDeactivate: [NSLayoutConstraint] = []

    override open func updateConstraints() {
        super.updateConstraints()

        defer {
            constraintsToActivate = []
            constraintsToDeactivate = []
        }

        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        NSLayoutConstraint.activate(constraintsToActivate)
    }

    open func updateThreadViews() {
        guard let message = message else { return /* todo */ }

        let isOutgoing = message.isSentByCurrentUser
        let isPartOfThread = message.isPartOfThread

        threadView.message = message

        threadArrowView.direction = isOutgoing ? .toLeading : .toTrailing

        threadView.isHidden = !isPartOfThread
        threadArrowView.isHidden = !isPartOfThread
        if isPartOfThread {
            if isOutgoing {
                constraintsToActivate.append(contentsOf: outgoingMessageIsThreadConstraints)
                constraintsToDeactivate.append(contentsOf: incomingMessageIsThreadConstraints)
            } else {
                constraintsToActivate.append(contentsOf: incomingMessageIsThreadConstraints)
                constraintsToDeactivate.append(contentsOf: outgoingMessageIsThreadConstraints)
            }
        } else {
            constraintsToDeactivate.append(contentsOf: outgoingMessageIsThreadConstraints)
            constraintsToDeactivate.append(contentsOf: incomingMessageIsThreadConstraints)
        }
    }

    // todo -> move to the avatar view itself
    open func updateAvatarView() {
        guard let message = message else { return /* todo */ }
        
        let placeholder = uiConfig.images.userAvatarPlaceholder1
        if let imageURL = message.author.imageURL {
            authorAvatarView.imageView.loadImage(from: imageURL, placeholder: placeholder)
        } else {
            authorAvatarView.imageView.image = placeholder
        }
        
        authorAvatarView.isVisible = !message.isSentByCurrentUser && message.isLastInGroup
    }
    
    open func updateReactionsView() {
        guard let message = message else { return /* todo */ }
        
        let userReactionIDs = Set(message.currentUserReactions.map(\.type))
        
        let isOutgoing = message.isSentByCurrentUser
        
        reactionsBubble.content = .init(
            style: isOutgoing ? .smallOutgoing : .smallIncoming,
            reactions: message.message.reactionScores.keys
                .sorted { $0.rawValue < $1.rawValue }
                .map { .init(type: $0, isChosenByCurrentUser: userReactionIDs.contains($0)) },
            didTapOnReaction: { _ in }
        )
        
        if message.deletedAt == nil && !message.reactionScores.isEmpty {
            constraintsToActivate.append(bubbleToReactionsConstraint!)
        } else {
            constraintsToDeactivate.append(bubbleToReactionsConstraint!)
        }
        
        reactionsBubble.isVisible = message.deletedAt == nil && !message.reactionScores.isEmpty
    }
    
    open func updateBubbleView() {
        guard let message = message else { return /* todo */ }
        
        messageBubbleView.message = message
        
        if message.isLastInGroup {
            constraintsToActivate.append(bubbleToMetadataConstraint!)
        } else {
            constraintsToDeactivate.append(bubbleToMetadataConstraint!)
        }
        
        if message.lastActionFailed {
            constraintsToActivate.append(bubbleToErrorIndicatorConstraint!)
        } else {
            constraintsToDeactivate.append(bubbleToErrorIndicatorConstraint!)
        }
        
        if message.type == .ephemeral {
            messageBubbleView.backgroundColor = uiConfig.colorPalette.popoverBackground
        } else if message.layoutOptions.contains(.linkPreview) {
            messageBubbleView.backgroundColor = uiConfig.colorPalette.highlightedAccentBackground1
        } else {
            messageBubbleView.backgroundColor = message.isSentByCurrentUser == true ?
                uiConfig.colorPalette.background2 :
                uiConfig.colorPalette.popoverBackground
        }
    }
    
    open func updateMetadataView() {
        messageMetadataView.message = message

        messageMetadataView.isVisible = message?.isLastInGroup ?? false
    }
    
    open func updateQuotedMessageView() {
        guard let message = message else { return /* todo */ }
        
        quotedMessageView.isParentMessageSentByCurrentUser = message.isSentByCurrentUser
        quotedMessageView.message = message.quotedMessage
        quotedMessageView.isVisible = message.layoutOptions.contains(.quotedMessage)
    }
    
    open func updateErrorIndicator() {
        errorIndicator.isVisible = message?.lastActionFailed ?? false
    }
    
    open func updateLinkPreviewView() {
        guard let message = message else { return /* todo */ }
        
        linkPreviewView.content = message.attachments.first { $0.type.isLink } as? ChatMessageDefaultAttachment
        
        linkPreviewView.isVisible = message.layoutOptions.contains(.linkPreview)
    }
    
    open func updateAttachmentsView() {
        guard let message = message else { return /* todo */ }
        
        attachmentsView.content = .init(
            attachments: message.attachments.compactMap { $0 as? ChatMessageDefaultAttachment },
            didTapOnAttachment: message.didTapOnAttachment,
            didTapOnAttachmentAction: message.didTapOnAttachmentAction
        )
        
        attachmentsView.isVisible = message.layoutOptions.contains(.attachments)
    }
    
    open func updateTextView() {
        guard let message = message else { return /* todo */ }
        
        let font: UIFont = uiConfig.font.body
        textView.attributedText = .init(string: message.textContent, attributes: [
            .foregroundColor: message.deletedAt == nil ? uiConfig.colorPalette.text : uiConfig.colorPalette.subtitleText,
            .font: message.deletedAt == nil ? font : font.italic
        ])
        
        textView.isVisible = message.layoutOptions.contains(.text)
    }
    
    open func updateMessagePosition() { // TODO find a better name
        if message?.isSentByCurrentUser ?? false {
            constraintsToActivate.append(contentsOf: outgoingMessageConstraints)
            constraintsToDeactivate.append(contentsOf: incomingMessageConstraints)
        } else {
            constraintsToActivate.append(contentsOf: incomingMessageConstraints)
            constraintsToDeactivate.append(contentsOf: outgoingMessageConstraints)
        }
    }

    // ======

    override open func updateContent() {
        // When message cell is about to be reused, it sets `nil` for message value.
        // That means we need to remove all dynamic constraints to prevent layout warnings.
        guard let message = self.message else {
            removeAllDynamicConstraints()
            return
        }

        // Base views in the message
        updateBubbleView()
        updateMetadataView()
        updateReactionsView()
        updateThreadViews()
        updateAvatarView()
        updateMessagePosition()
        updateErrorIndicator()
        updateQuotedMessageView()

        // Additional views
        updateTextView()
        updateLinkPreviewView()
        updateAttachmentsView()
        
        // Necessary cnstraints
        layoutConstraints.values.flatMap { $0 }.forEach { constraintsToDeactivate.append($0) }
        layoutConstraints[message.layoutOptions]?.forEach { constraintsToActivate.append($0) }

        setNeedsUpdateConstraints()
    }

    // MARK: - Actions

    @objc open func didTapOnErrorIndicator() {
        onErrorIndicatorTap(message)
    }

    @objc func didTapOnThread() {
        onThreadTap(message)
    }
    
    @objc func didTapOnLinkPreview() {
        onLinkTap(linkPreviewView.content)
    }
}

public struct ChatMessageContentViewLayoutOptions: OptionSet, Hashable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let text = Self(rawValue: 1 << 0)
    public static let attachments = Self(rawValue: 1 << 1)
    public static let quotedMessage = Self(rawValue: 1 << 2)
    public static let linkPreview = Self(rawValue: 1 << 3)
    
    public static let all: Self = [.text, .attachments, .quotedMessage, .linkPreview]
}

// MARK: - TextOnlyContentView

public class ChatMessageTextContentView<ExtraData: ExtraDataTypes>: _ChatMessageContentView<ExtraData> {
    override open func updateContent() {
        // When message cell is about to be reused, it sets `nil` for message value.
        // That means we need to remove all dynamic constraints to prevent layout warnings.
        guard let message = self.message else {
            removeAllDynamicConstraints()
            return
        }
        
        let isOutgoing = message.isSentByCurrentUser
        
        messageBubbleView.message = message
        messageMetadataView.message = message
        
        let userReactionIDs = Set(message.currentUserReactions.map(\.type))
        
        reactionsBubble.content = .init(
            style: isOutgoing ? .smallOutgoing : .smallIncoming,
            reactions: message.message.reactionScores.keys
                .sorted { $0.rawValue < $1.rawValue }
                .map { .init(type: $0, isChosenByCurrentUser: userReactionIDs.contains($0)) },
            didTapOnReaction: { _ in }
        )
        
        updateThreadViews()
        updateAvatarView()
        
        if isOutgoing {
            constraintsToActivate.append(contentsOf: outgoingMessageConstraints)
            constraintsToDeactivate.append(contentsOf: incomingMessageConstraints)
        } else {
            constraintsToActivate.append(contentsOf: incomingMessageConstraints)
            constraintsToDeactivate.append(contentsOf: outgoingMessageConstraints)
        }
        
        let shouldAddBubbleToReactionsConstraint = message.deletedAt == nil && !message.reactionScores.isEmpty
        if shouldAddBubbleToReactionsConstraint {
            constraintsToActivate.append(bubbleToReactionsConstraint!)
        } else {
            constraintsToDeactivate.append(bubbleToReactionsConstraint!)
        }
        
        if message.isLastInGroup {
            constraintsToActivate.append(bubbleToMetadataConstraint!)
        } else {
            constraintsToDeactivate.append(bubbleToMetadataConstraint!)
        }
        
        if message.lastActionFailed {
            constraintsToActivate.append(bubbleToErrorIndicatorConstraint!)
        } else {
            constraintsToDeactivate.append(bubbleToErrorIndicatorConstraint!)
        }
        
        constraintsToActivate += [
            textView.leadingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.leadingAnchor),
            textView.trailingAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.trailingAnchor),
            textView.topAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.topAnchor),
            textView.bottomAnchor.pin(equalTo: messageBubbleView.layoutMarginsGuide.bottomAnchor)
        ]
        
        //        NSLayoutConstraint.deactivate(constraintsToDeactivate)
        //        NSLayoutConstraint.activate(constraintsToActivate)
        
        authorAvatarView.isVisible = !isOutgoing && message.isLastInGroup
        messageMetadataView.isVisible = message.isLastInGroup
        reactionsBubble.isVisible = shouldAddBubbleToReactionsConstraint
        errorIndicator.isVisible = message.lastActionFailed
        
        // --
        
        
        //
        //
        //        let layoutOptions = message.layoutOptions
        //
        //        quotedMessageView.isParentMessageSentByCurrentUser = message.isSentByCurrentUser
        //        quotedMessageView.message = message.quotedMessage
        quotedMessageView.isVisible = false
        //
        let font: UIFont = uiConfig.font.body
        textView.attributedText = .init(string: message.textContent, attributes: [
            .foregroundColor: message.deletedAt == nil ? uiConfig.colorPalette.text : uiConfig.colorPalette.subtitleText,
            .font: message.deletedAt == nil ? font : font.italic
        ])
        textView.isVisible = true
        //
        //        if message.type == .ephemeral {
        //            messageBubbleView.backgroundColor = uiConfig.colorPalette.popoverBackground
        //        } else if layoutOptions.contains(.linkPreview) {
        //            messageBubbleView.backgroundColor = uiConfig.colorPalette.highlightedAccentBackground1
        //        } else {
                    messageBubbleView.backgroundColor = message.isSentByCurrentUser == true ?
                        uiConfig.colorPalette.background2 :
                        uiConfig.colorPalette.popoverBackground
        //        }
        //
        //        linkPreviewView.content = message.attachments.first { $0.type.isLink } as? ChatMessageDefaultAttachment
        //
        //        linkPreviewView.isVisible = layoutOptions.contains(.linkPreview)
        //
        //        attachmentsView.content = .init(
        //            attachments: message.attachments.compactMap { $0 as? ChatMessageDefaultAttachment },
        //            didTapOnAttachment: message.didTapOnAttachment,
        //            didTapOnAttachmentAction: message.didTapOnAttachmentAction
        //        )
        //
        //        attachmentsView.isVisible = layoutOptions.contains(.attachments)
        //
        //        layoutConstraints.values.flatMap { $0 }.forEach { $0.isActive = false }
        //        layoutConstraints[layoutOptions]?.forEach { $0.isActive = true }
        
        // --
        
        setNeedsUpdateConstraints()
    }
}

// MARK: - Extensions

extension _ChatMessageGroupPart {
    var textContent: String {
        guard message.type != .ephemeral else {
            return ""
        }
        
        guard message.deletedAt == nil else {
            return L10n.Message.deletedMessagePlaceholder
        }
        
        return message.text
    }
}

extension _ChatMessageGroupPart {
    var layoutOptions: ChatMessageContentViewLayoutOptions {
        guard message.deletedAt == nil else {
            return [.text]
        }
        
        var options: ChatMessageContentViewLayoutOptions = []
        
        if !textContent.isEmpty {
            options.insert(.text)
        }
        
        if quotedMessage != nil {
            options.insert(.quotedMessage)
        }
        
        if message.attachments.contains(where: { $0.type == .image || $0.type == .giphy || $0.type == .file }) {
            options.insert(.attachments)
        } else if message.attachments.contains(where: { $0.type.isLink }) {
            // link preview is visible only when no other attachments available
            options.insert(.linkPreview)
        }
        
        return options
    }
}
