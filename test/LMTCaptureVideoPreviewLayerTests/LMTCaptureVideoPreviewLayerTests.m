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

- (void)testImageIsNotNil {
    
    // Create the session video preview layer
    LMTCaptureVideoPreviewLayer * videoPreviewLayer = [[LMTCaptureVideoPreviewLayer alloc] initWithSession:nil];
    [videoPreviewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer
    [videoPreviewLayer setBlur:1.0];
    
    // Inject the mock object for LMTCaptureVideoPreviewLayerInternal
    MockLMTCaptureVideoPreviewLayerInternal * mockLMTCaptureVideoPreviewLayerInternal = [MockLMTCaptureVideoPreviewLayerInternal new];
    mockLMTCaptureVideoPreviewLayerInternal.sampleBufferImage = [UIImage imageNamed:@"test-screenshot-1.png" inBundle:[NSBundle bundleForClass:[self class]] compatibleWithTraitCollection:nil];
    [videoPreviewLayer setInternal:mockLMTCaptureVideoPreviewLayerInternal];
    
    // Set bounds and draw once
    videoPreviewLayer.bounds = CGRectMake(0, 0, 375, 667);
    [videoPreviewLayer layoutIfNeeded];
    [videoPreviewLayer performSelectorOnMainThread:@selector(drawPixelBuffer:) withObject:nil waitUntilDone:YES];
    
    UIImage * image = [UIImage imageFromLayer:videoPreviewLayer];
    
    XCTAssertNotNil(image, @"Image is nil");
}

//- (void)testPerformanceExample {
//    // This is an example of a performance test case.
//    [self measureBlock:^{
//        // Put the code you want to measure the time of here.
//    }];
//}

@end
