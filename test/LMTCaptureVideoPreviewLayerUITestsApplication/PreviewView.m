/*
 
 PreviewView.m
 LMTCaptureVideoPreviewLayer UI Tests Application
 
 Copyright (c) 2016 Coletiv Studio.
 Some rights reserved, all wrongs deserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
 the Software, and to permit persons to whom the Software is furnished to do so,
 subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "PreviewView.h"

#if TARGET_OS_SIMULATOR
#import "MockLMTCaptureVideoPreviewLayerInternal.h"
#endif

@implementation PreviewView

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // IMPORTANT
    _videoPreviewLayer.frame = self.bounds;
}

#pragma mark -
#pragma mark Preview Layer

- (void)setCaptureSession:(id)captureSession
{
#if !TARGET_OS_SIMULATOR
    if (captureSession)
#endif
    {
        // Create the session video preview layer
        LMTCaptureVideoPreviewLayer * videoPreviewLayer = [[LMTCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
        [videoPreviewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer
    
#if TARGET_OS_SIMULATOR
        // Inject the mock object for LMTCaptureVideoPreviewLayerInternal
        MockLMTCaptureVideoPreviewLayerInternal * mockInternal = [MockLMTCaptureVideoPreviewLayerInternal new];
        mockInternal.delegate = videoPreviewLayer;
        [videoPreviewLayer setInternal:mockInternal];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [mockInternal simulateCaptureSessionDidStopRunningNotification];
        });
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [mockInternal simulateCaptureSessionDidStartRunningNotification];
        });
#endif
        
        [self setVideoPreviewLayer:videoPreviewLayer];
        [videoPreviewLayer setBlur:0.0];
    }
}

- (void)setVideoPreviewLayer:(LMTCaptureVideoPreviewLayer *)videoPreviewLayer
{
    if (videoPreviewLayer)
    {
        _videoPreviewLayer = videoPreviewLayer;
        
        [self.layer setMasksToBounds:YES];
        [self.layer addSublayer:_videoPreviewLayer];
    }
    else
    {
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = nil;
    }
}

@end
