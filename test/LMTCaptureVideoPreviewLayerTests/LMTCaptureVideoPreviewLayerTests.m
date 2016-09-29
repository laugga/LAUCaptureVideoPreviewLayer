//
//  LMTCaptureVideoPreviewLayerUnitTests.m
//  LMTCaptureVideoPreviewLayerUnitTests
//
//  Created by Luis Laugga on 9/20/16.
//  Copyright © 2016 Luis Laugga. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "UIImage+Compare.h"

#import "LMTCaptureVideoPreviewLayer.h"
#import "MockLMTCaptureVideoPreviewLayerInternal.h"

@interface LMTCaptureVideoPreviewLayerTests : XCTestCase

@end

@implementation LMTCaptureVideoPreviewLayerTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSourceImageIsNotNil {
    
    // Create the session video preview layer
    LMTCaptureVideoPreviewLayer * videoPreviewLayer = [[LMTCaptureVideoPreviewLayer alloc] initWithSession:nil];
    [videoPreviewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer
    
    // Inject the mock object for LMTCaptureVideoPreviewLayerInternal
    MockLMTCaptureVideoPreviewLayerInternal * mockLMTCaptureVideoPreviewLayerInternal = [MockLMTCaptureVideoPreviewLayerInternal new];
    mockLMTCaptureVideoPreviewLayerInternal.sampleBufferImage = [UIImage imageNamed:@"source-image.png" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    [videoPreviewLayer setInternal:mockLMTCaptureVideoPreviewLayerInternal];
    
    // Set bounds and draw once
    videoPreviewLayer.bounds = CGRectMake(0, 0, 375, 667);
    [videoPreviewLayer layoutIfNeeded];
    [videoPreviewLayer performSelectorOnMainThread:@selector(drawPixelBuffer:) withObject:nil waitUntilDone:YES];
    [videoPreviewLayer setBlur:1.0];
    
    UIImage * sourceImage = [UIImage imageFromLayer:videoPreviewLayer];
    
    XCTAssertNotNil(sourceImage, @"Image is nil");

    CGFloat similarity = [sourceImage similarityWithImage:sourceImage];
    
    XCTAssertTrue(similarity == 0.0f, @"Images must be the same");
}

- (void)testRenderedImageSimilarityWithTargetImage {
    
    UIImage * targetImage1 = [UIImage imageNamed:@"target-image-12px-radius.png" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    UIImage * targetImage2 = [UIImage imageNamed:@"target-image-36px-radius.png" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    UIImage * targetImage3 = [UIImage imageNamed:@"target-image-48px-radius.png" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    
    // Create the session video preview layer
    LMTCaptureVideoPreviewLayer * videoPreviewLayer = [[LMTCaptureVideoPreviewLayer alloc] initWithSession:nil];
    [videoPreviewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer
    
    // Inject the mock object for LMTCaptureVideoPreviewLayerInternal
    MockLMTCaptureVideoPreviewLayerInternal * mockLMTCaptureVideoPreviewLayerInternal = [MockLMTCaptureVideoPreviewLayerInternal new];
    mockLMTCaptureVideoPreviewLayerInternal.sampleBufferImage = [UIImage imageNamed:@"source-image.png" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    [videoPreviewLayer setInternal:mockLMTCaptureVideoPreviewLayerInternal];
    // Set bounds and draw once
    videoPreviewLayer.bounds = CGRectMake(0, 0, 375, 667);
    [videoPreviewLayer layoutIfNeeded];
    [videoPreviewLayer performSelectorOnMainThread:@selector(drawPixelBuffer:) withObject:nil waitUntilDone:YES];
    [videoPreviewLayer setBlur:1.0];
    
    UIImage * renderedImage = [UIImage imageFromLayer:videoPreviewLayer];
    
    CGFloat similarity1 = [renderedImage similarityWithImage:targetImage1];
    CGFloat similarity2 = [renderedImage similarityWithImage:targetImage2];
    CGFloat similarity3 = [renderedImage similarityWithImage:targetImage3];
    
    NSLog(@"*** Similarity between rendered image and reference image 1 is %f ***", similarity1);
    NSLog(@"*** Similarity between rendered image and reference image 2 is %f ***", similarity2);
    NSLog(@"*** Similarity between rendered image and reference image 3 is %f ***", similarity3);
    
    XCTAssertTrue(similarity2 < 0.1f, @"For Radius = 36px the images must be the similar within 0.1 tolerance");
    XCTAssertTrue(similarity3 < 0.08f, @"For Radius = 48px the images must be the similar within 0.08 tolerance");
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
