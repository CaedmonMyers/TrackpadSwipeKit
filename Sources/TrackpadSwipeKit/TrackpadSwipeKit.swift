// The Swift Programming Language
// https://docs.swift.org/swift-book
//
// Swipe Test
// SwipableView.swift
//
// Created on 13/02/2026
//
// Copyright ©2026 DoorHinge Apps.
//


import Foundation
import AppKit
import SwiftUI

// MARK: - View Extension

public extension View {
    func onTrackpadSwipe(
        sensitivity: CGFloat = 1.0,
        minDistance: CGFloat? = nil,
        maxDistance: CGFloat? = nil,
        onSwipe: @escaping (CGFloat) -> Void,
        onSwipeEnded: @escaping (CGFloat) -> Void
    ) -> some View {
        self.modifier(
            SwipeGestureModifier(
                onSwipe: onSwipe,
                onSwipeEnded: onSwipeEnded,
                sensitivity: sensitivity,
                minDistance: minDistance,
                maxDistance: maxDistance
            )
        )
    }
}

// MARK: - View Modifier

struct SwipeGestureModifier: ViewModifier {
    var onSwipe: (CGFloat) -> Void
    var onSwipeEnded: (CGFloat) -> Void
    var sensitivity: CGFloat
    var minDistance: CGFloat?
    var maxDistance: CGFloat?

    func body(content: Content) -> some View {
        content
            .overlay(
                SwipableView(
                    onSwipe: onSwipe,
                    onSwipeEnded: onSwipeEnded,
                    sensitivity: sensitivity,
                    minDistance: minDistance,
                    maxDistance: maxDistance
                )
                .allowsHitTesting(true)
            )
    }
}

// MARK: - NSViewRepresentable

struct SwipableView: NSViewRepresentable {
    var onSwipe: (CGFloat) -> Void
    var onSwipeEnded: (CGFloat) -> Void
    var sensitivity: CGFloat = 1.0
    var minDistance: CGFloat? = nil
    var maxDistance: CGFloat? = nil

    func makeNSView(context: Context) -> SwipeDetectingView {
        let view = SwipeDetectingView()
        view.onSwipe = onSwipe
        view.onSwipeEnded = onSwipeEnded
        view.sensitivity = sensitivity
        view.minDistance = minDistance
        view.maxDistance = maxDistance
        return view
    }

    func updateNSView(_ nsView: SwipeDetectingView, context: Context) {
        nsView.onSwipe = onSwipe
        nsView.onSwipeEnded = onSwipeEnded
        nsView.sensitivity = sensitivity
        nsView.minDistance = minDistance
        nsView.maxDistance = maxDistance
    }
}

// MARK: - AppKit View

class SwipeDetectingView: NSView {
    var onSwipe: ((CGFloat) -> Void)?
    var onSwipeEnded: ((CGFloat) -> Void)?
    var sensitivity: CGFloat = 1.0
    var minDistance: CGFloat? = nil
    var maxDistance: CGFloat? = nil

    private var panGestureRecognizer: NSPanGestureRecognizer!
    private var totalTranslation: CGFloat = 0
    private var isTracking = false
    private var scrollMomentumTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGestureRecognizer()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestureRecognizer()
    }

    private func setupGestureRecognizer() {
        // Enable layer backing for better event handling
        wantsLayer = true

        // Set up pan gesture for mouse dragging
        panGestureRecognizer = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        // Left mouse button
        panGestureRecognizer.buttonMask = 0x1
        addGestureRecognizer(panGestureRecognizer)
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    private func clampDistance(_ distance: CGFloat) -> CGFloat {
        var result = distance * sensitivity
        if let min = minDistance {
            result = max(result, min)
        }
        if let max = maxDistance {
            result = min(result, max)
        }
        return result
    }

    // Handle mouse dragging via gesture recognizer
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let horizontalDistance = translation.x

        switch gesture.state {
        case .began:
            totalTranslation = 0
            isTracking = true

        case .changed:
            totalTranslation = horizontalDistance
            let clampedDistance = clampDistance(totalTranslation)
            onSwipe?(clampedDistance)

        case .ended, .cancelled:
            let clampedDistance = clampDistance(totalTranslation)
            onSwipeEnded?(clampedDistance)
            totalTranslation = 0
            isTracking = false

        default:
            break
        }
    }

    // Handle trackpad swipes via scrollWheel events
    override func scrollWheel(with event: NSEvent) {
        // Cancel any existing momentum timer
        scrollMomentumTimer?.invalidate()

        // Use deltaX for horizontal scrolling
        let deltaX = event.scrollingDeltaX

        if event.phase == .began {
            totalTranslation = 0
            isTracking = true
        }

        if event.phase == .changed || event.phase == [] {
            totalTranslation += deltaX
            let clampedDistance = clampDistance(totalTranslation)
            onSwipe?(clampedDistance)
        }

        if event.phase == .ended || event.phase == .cancelled {
            let clampedDistance = clampDistance(totalTranslation)
            onSwipeEnded?(clampedDistance)

            // Set a short timer to reset after momentum ends
            scrollMomentumTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.totalTranslation = 0
                self?.isTracking = false
            }
        }

        // Handle momentum phase separately
        if event.momentumPhase == .ended {
            let clampedDistance = clampDistance(totalTranslation)
            onSwipeEnded?(clampedDistance)
            totalTranslation = 0
            isTracking = false
        }
    }
}
