/*
 
 CameraPreviewView.m
 LMTCaptureVideoPreviewLayerExample
 
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

#import "CameraPreviewView.h"

@implementation CameraPreviewView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        UILongPressGestureRecognizer * longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(userDidLongPress:)];
        longPressGestureRecognizer.minimumPressDuration = 0.01;
        [self addGestureRecognizer:longPressGestureRecognizer];
    }
    
    return self;
}

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
    if (captureSession)
    {
        // Create the session video preview layer
        LMTCaptureVideoPreviewLayer * videoPreviewLayer = [[LMTCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
        [videoPreviewLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
        [videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill]; // fill the layer

        [self setVideoPreviewLayer:videoPreviewLayer];
    }
    else
    {
        // Remove preview layer from superview
        [self setVideoPreviewLayer:nil];
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

- (void)userDidLongPress:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan)
    {
        // Switch to blur = 1.0 when user presses
        _videoPreviewLayer.blur = 1.0;
    }
    else if (sender.state == UIGestureRecognizerStateEnded || sender.state == UIGestureRecognizerStateFailed)
    {
        // Turn blur off when user stops pressing
        _videoPreviewLayer.blur = 0.0f;
    }
}

@end
