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
        threshold: CGFloat = 10,
        onSwipe: @escaping (CGFloat) -> Void,
        onSwipeEnded: @escaping (CGFloat) -> Void
    ) -> some View {
        self.modifier(
            SwipeGestureModifier(
                onSwipe: onSwipe,
                onSwipeEnded: onSwipeEnded,
                sensitivity: sensitivity,
                minDistance: minDistance,
                maxDistance: maxDistance,
                threshold: threshold
            )
        )
    }
}

// MARK: - View Modifier

public struct SwipeGestureModifier: ViewModifier {
    var onSwipe: (CGFloat) -> Void
    var onSwipeEnded: (CGFloat) -> Void
    var sensitivity: CGFloat
    var minDistance: CGFloat?
    var maxDistance: CGFloat?
    var threshold: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay(
                SwipableView(
                    onSwipe: onSwipe,
                    onSwipeEnded: onSwipeEnded,
                    sensitivity: sensitivity,
                    minDistance: minDistance,
                    maxDistance: maxDistance,
                    threshold: threshold
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
    var threshold: CGFloat = 10

    func makeNSView(context: Context) -> SwipeDetectingView {
        let view = SwipeDetectingView()
        view.onSwipe = onSwipe
        view.onSwipeEnded = onSwipeEnded
        view.sensitivity = sensitivity
        view.minDistance = minDistance
        view.maxDistance = maxDistance
        view.threshold = threshold
        return view
    }

    func updateNSView(_ nsView: SwipeDetectingView, context: Context) {
        nsView.onSwipe = onSwipe
        nsView.onSwipeEnded = onSwipeEnded
        nsView.sensitivity = sensitivity
        nsView.minDistance = minDistance
        nsView.maxDistance = maxDistance
        nsView.threshold = threshold
    }
}

// MARK: - AppKit View

class SwipeDetectingView: NSView {
    var onSwipe: ((CGFloat) -> Void)?
    var onSwipeEnded: ((CGFloat) -> Void)?
    var sensitivity: CGFloat = 1.0
    var minDistance: CGFloat? = nil
    var maxDistance: CGFloat? = nil
    var threshold: CGFloat = 10

    private var panGestureRecognizer: NSPanGestureRecognizer!
    private var totalTranslation: CGFloat = 0
    private var isTracking = false
    private var gestureActivated = false
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
            gestureActivated = false

        case .changed:
            totalTranslation = horizontalDistance

            // Only activate if threshold is exceeded
            if !gestureActivated && abs(totalTranslation) >= threshold {
                gestureActivated = true
            }

            if gestureActivated {
                let clampedDistance = clampDistance(totalTranslation)
                onSwipe?(clampedDistance)
            }

        case .ended, .cancelled:
            if gestureActivated {
                let clampedDistance = clampDistance(totalTranslation)
                onSwipeEnded?(clampedDistance)
            }
            totalTranslation = 0
            isTracking = false
            gestureActivated = false

        default:
            break
        }
    }

    // Handle trackpad swipes via scrollWheel events
    override func scrollWheel(with event: NSEvent) {
        let deltaX = event.scrollingDeltaX
        let deltaY = event.scrollingDeltaY

        // Check if this is primarily vertical scrolling
        let isVerticalScrolling = abs(deltaY) > abs(deltaX)

        // If vertical scrolling is dominant, pass through to allow normal scrolling
        if isVerticalScrolling && !gestureActivated {
            super.scrollWheel(with: event)
            return
        }

        // Cancel any existing momentum timer
        scrollMomentumTimer?.invalidate()

        if event.phase == .began {
            totalTranslation = 0
            isTracking = true
            gestureActivated = false
        }

        if event.phase == .changed || event.phase == [] {
            totalTranslation += deltaX

            // Only activate gesture if horizontal threshold is exceeded
            if !gestureActivated && abs(totalTranslation) >= threshold {
                gestureActivated = true
            }

            // Only send callbacks if gesture is activated
            if gestureActivated {
                let clampedDistance = clampDistance(totalTranslation)
                onSwipe?(clampedDistance)
            } else if !isTracking {
                // If we're not tracking and not activated, pass through
                super.scrollWheel(with: event)
            }
        }

        if event.phase == .ended || event.phase == .cancelled {
            if gestureActivated {
                let clampedDistance = clampDistance(totalTranslation)
                onSwipeEnded?(clampedDistance)
            }

            // Set a short timer to reset after momentum ends
            scrollMomentumTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                self?.totalTranslation = 0
                self?.isTracking = false
                self?.gestureActivated = false
            }
        }

        // Handle momentum phase separately
        if event.momentumPhase == .ended {
            if gestureActivated {
                let clampedDistance = clampDistance(totalTranslation)
                onSwipeEnded?(clampedDistance)
            }
            totalTranslation = 0
            isTracking = false
            gestureActivated = false
        }
    }
}
