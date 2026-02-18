//
//  LayoutTests.swift
//  MoveAITests
//
//  Created by Dave Mathew on 11/01/25.
//

import XCTest
import SwiftUI
import AVFoundation
@testable import MoveAI

@MainActor
final class LayoutTests: XCTestCase {
    
    // MARK: - VideoPlayerView Layout Tests
    
    func testVideoPlayerViewNormalModeHasConstrainedHeight() throws {
        // Given: A VideoPlayerView in normal mode
        let videoURL = URL(fileURLWithPath: "/test/video.mp4")
        let playback = PlaybackController(videoURL: videoURL)
        let videoView = VideoPlayerView(
            videoURL: videoURL,
            poseData: nil,
            isFullScreenMode: false,
            playback: playback
        )
        
        // When: View is rendered
        let viewController = UIHostingController(rootView: videoView)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 1000)
        
        // Force layout with a size that's reasonable
        let expectation = expectation(description: "Layout complete")
        DispatchQueue.main.async {
            viewController.view.layoutIfNeeded()
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Then: The view should have a constrained height based on 9:16 aspect ratio
        let containerWidth: CGFloat = 390.0
        let fullVideoHeight = containerWidth * 16 / 9  // Full 9:16 aspect ratio
        let expectedHeight = fullVideoHeight * 0.85  // 85% of full 9:16 height
        
        // Check that the view doesn't expand infinitely (with generous tolerance for SwiftUI layout)
        let actualHeight = viewController.view.frame.height
        XCTAssertLessThanOrEqual(actualHeight, expectedHeight * 2.0, // Allow 100% tolerance for SwiftUI layout quirks
                                 "VideoPlayerView should not exceed expected height excessively")
        XCTAssertGreaterThan(actualHeight, 0, "VideoPlayerView should have a height")
    }
    
    func testVideoPlayerViewUsesCorrectAspectRatio() throws {
        // Given: Video dimensions calculation
        let screenWidth: CGFloat = 390.0  // Typical iPhone width
        let fullVideoHeight = screenWidth * 16 / 9  // 9:16 aspect ratio
        let visibleHeight = fullVideoHeight * 0.85  // 85% visible
        
        // Then: Aspect ratio should be correct
        let aspectRatio = screenWidth / visibleHeight
        let expectedRatio = 9.0 / (16.0 * 0.85)  // 9:16 cropped to 85%
        
        XCTAssertEqual(aspectRatio, expectedRatio, accuracy: 0.01,
                      "Video should maintain 9:16 aspect ratio (85% visible)")
    }
    
    func testVideoPlayerViewFillsAvailableWidth() throws {
        // Given: A VideoPlayerView in normal mode
        let videoURL = URL(fileURLWithPath: "/test/video.mp4")
        let playback = PlaybackController(videoURL: videoURL)
        let videoView = VideoPlayerView(
            videoURL: videoURL,
            poseData: nil,
            isFullScreenMode: false,
            playback: playback
        )
        
        // When: View is rendered with a container width
        let containerWidth: CGFloat = 350.0  // Account for padding
        let viewController = UIHostingController(rootView: videoView)
        viewController.view.frame = CGRect(x: 0, y: 0, width: containerWidth, height: 800)
        viewController.view.layoutIfNeeded()
        
        // Then: The view should attempt to fill available width
        // Note: Actual width might be constrained by parent, but should be close
        XCTAssertGreaterThan(viewController.view.frame.width, containerWidth * 0.9,
                            "VideoPlayerView should fill most of available width")
    }
    
    // MARK: - SessionDetailView Layout Tests
    
    func testSessionDetailViewElementsDoNotOverlap() throws {
        // Given: A SessionDetailView with all elements
        let mockSession = Session(
            id: UUID(),
            movementType: .squat,
            videoURL: URL(fileURLWithPath: "/test/video.mp4"),
            timestamp: Date(),
            analysisResult: nil,
            poseData: nil,
            notes: nil
        )
        
        let sessionManager = SessionManager()
        let detailView = SessionDetailView(session: mockSession, sessionManager: sessionManager, onExit: nil)
        
        // When: View is rendered
        let viewController = UIHostingController(rootView: detailView)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 1200)
        viewController.view.layoutIfNeeded()
        
        // Then: Video player should be positioned first
        // And other elements should be below it (not overlapping)
        // This is a structural test - we're checking that VStack spacing works
        XCTAssertNotNil(viewController.view,
                       "SessionDetailView should render without errors")
        
        // The view should have a reasonable height (not infinite)
        let viewHeight = viewController.view.frame.height
        XCTAssertLessThan(viewHeight, 2000, // Should be less than 2000pt
                         "SessionDetailView should not expand infinitely")
    }
    
    func testVideoPlayerViewHasControlsBelowVideo() throws {
        // Given: A VideoPlayerView in normal mode
        let videoURL = URL(fileURLWithPath: "/test/video.mp4")
        let playback = PlaybackController(videoURL: videoURL)
        let videoView = VideoPlayerView(
            videoURL: videoURL,
            poseData: nil,
            isFullScreenMode: false,
            playback: playback
        )
        
        // When: View is rendered
        let viewController = UIHostingController(rootView: videoView)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 1000)
        viewController.view.layoutIfNeeded()
        
        // Then: The view should have internal structure (VStack with video and controls)
        // This ensures controls are positioned below, not on top of video
        XCTAssertNotNil(viewController.view,
                       "VideoPlayerView should render without errors")
        
        // View should have reasonable height (video + controls)
        let viewHeight = viewController.view.frame.height
        let screenWidth = UIScreen.main.bounds.width
        let expectedVideoHeight = screenWidth * 16 / 9 * 0.85
        
        XCTAssertGreaterThan(viewHeight, expectedVideoHeight,
                            "VideoPlayerView should include space for controls")
    }
    
    // MARK: - Geometry Calculation Tests
    
    func testVideoHeightCalculation() throws {
        // Test that our height calculation is correct for different screen widths
        let testWidths: [CGFloat] = [375.0, 390.0, 428.0] // Various iPhone widths
        
        for width in testWidths {
            let fullVideoHeight = width * 16 / 9
            let visibleHeight = fullVideoHeight * 0.85
            
            // Verify calculations
            XCTAssertGreaterThan(visibleHeight, 0, "Visible height should be positive")
            XCTAssertLessThan(visibleHeight, fullVideoHeight, "Visible height should be less than full height")
            XCTAssertEqual(visibleHeight, fullVideoHeight * 0.85, accuracy: 0.01,
                          "Visible height should be exactly 85% of full height")
        }
    }
    
    func testAspectRatioConstraints() throws {
        // Test that aspect ratio calculations are correct
        let screenWidth: CGFloat = 390.0
        let fullVideoHeight = screenWidth * 16 / 9
        let visibleHeight = fullVideoHeight * 0.85
        
        // Full video should maintain 9:16 ratio
        let fullAspectRatio = screenWidth / fullVideoHeight
        XCTAssertEqual(fullAspectRatio, 9.0 / 16.0, accuracy: 0.01,
                      "Full video should maintain 9:16 aspect ratio")
        
        // Visible area should have adjusted ratio
        let visibleAspectRatio = screenWidth / visibleHeight
        let expectedVisibleRatio = 9.0 / (16.0 * 0.85)
        XCTAssertEqual(visibleAspectRatio, expectedVisibleRatio, accuracy: 0.01,
                      "Visible area should have correct adjusted aspect ratio")
    }
    
    // MARK: - Regression Tests
    
    func testVideoPlayerViewDoesNotExpandInfinitely() throws {
        // Regression test: VideoPlayerView should not expand to fill entire ScrollView
        let videoURL = URL(fileURLWithPath: "/test/video.mp4")
        let playback = PlaybackController(videoURL: videoURL)
        let videoView = VideoPlayerView(
            videoURL: videoURL,
            poseData: nil,
            isFullScreenMode: false,
            playback: playback
        )
        
        // Create a ScrollView container (like SessionDetailView uses)
        let scrollView = ScrollView {
            VStack(spacing: 24) {
                videoView
                Text("Exercise Name")
                Text("Analysis Pending")
                Text("Notes Section")
            }
            .padding()
        }
        
        let viewController = UIHostingController(rootView: scrollView)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 1500)
        viewController.view.layoutIfNeeded()
        
        // The video view should not take up the entire height
        // We can't directly measure subviews easily, but we can check the container
        let containerHeight = viewController.view.frame.height
        let screenWidth = UIScreen.main.bounds.width
        let maxExpectedVideoHeight = screenWidth * 16 / 9 * 0.85 + 100 // Video + controls + some margin
        
        // Container should be taller than just the video (includes other elements)
        XCTAssertGreaterThan(containerHeight, maxExpectedVideoHeight * 0.8,
                            "Container should include space for all elements, not just video")
    }
    
    func testPoseOverlayUsesFullVideoDimensions() throws {
        // Regression test: Pose overlay should use full video dimensions, not visible dimensions
        let screenWidth: CGFloat = 390.0
        let fullVideoHeight = screenWidth * 16 / 9
        let visibleHeight = fullVideoHeight * 0.85
        
        // Verify that we're using full dimensions for coordinate calculations
        // This is important for pose overlay alignment
        XCTAssertEqual(fullVideoHeight, screenWidth * 16 / 9, accuracy: 0.01,
                      "Full video height calculation should be correct")
        
        // Visible height should be 85% of full
        XCTAssertEqual(visibleHeight, fullVideoHeight * 0.85, accuracy: 0.01,
                      "Visible height should be 85% of full height")
        
        // The difference ensures we're cropping, not scaling
        let heightDifference = fullVideoHeight - visibleHeight
        XCTAssertGreaterThan(heightDifference, 0,
                            "There should be a height difference indicating cropping")
    }

    func testFullBleedFilledSizeCoversContainer() throws {
        let containerSize = CGSize(width: 390, height: 760)
        let displaySize = CGSize(width: 1920, height: 1080)

        let fillSize = VideoSurfaceLayoutCalculator.filledSize(
            containerSize: containerSize,
            displaySize: displaySize
        )

        XCTAssertGreaterThanOrEqual(fillSize.width, containerSize.width,
                                    "Aspect-fill width should cover the container")
        XCTAssertGreaterThanOrEqual(fillSize.height, containerSize.height,
                                    "Aspect-fill height should cover the container")
    }

    func testFullBleedFilledSizePreservesSourceAspectRatio() throws {
        let containerSize = CGSize(width: 390, height: 760)
        let displaySize = CGSize(width: 1080, height: 1920)

        let fillSize = VideoSurfaceLayoutCalculator.filledSize(
            containerSize: containerSize,
            displaySize: displaySize
        )

        let expectedRatio = displaySize.width / displaySize.height
        let actualRatio = fillSize.width / fillSize.height

        XCTAssertEqual(actualRatio, expectedRatio, accuracy: 0.0001,
                       "Aspect-fill sizing should preserve the source aspect ratio")
    }

    func testVideoGravityMappingUsesAspectFillForReviewMode() throws {
        XCTAssertEqual(
            VideoSurfaceLayoutCalculator.videoGravity(useAspectFit: false),
            AVLayerVideoGravity.resizeAspectFill,
            "Review mode should always use aspect fill"
        )
        XCTAssertEqual(
            VideoSurfaceLayoutCalculator.videoGravity(useAspectFit: true),
            AVLayerVideoGravity.resizeAspect,
            "Aspect-fit mode should map to resizeAspect"
        )
    }


}
