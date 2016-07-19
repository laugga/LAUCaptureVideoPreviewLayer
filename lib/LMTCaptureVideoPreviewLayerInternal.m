/*
 
 LMTCaptureVideoPreviewLayerInternal.m
 LMTCaptureVideoPreviewLayer
 
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

#import "LMTCaptureVideoPreviewLayerInternal.h"

@interface LMTCaptureVideoPreviewLayerInternal () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession * _session;
    AVCaptureVideoDataOutput * _videoDataOutput;
    dispatch_queue_t _videoDataOutputSampleBufferDelegateQueue;
    CMSampleBufferRef _videoDataOutputSampleBuffer;
}
@end

@implementation LMTCaptureVideoPreviewLayerInternal

#pragma mark -
#pragma mark AVCaptureSession

- (void)setSession:(AVCaptureSession *)session
{
    if (_session)
    {
        // TODO
    }
    
    _session = session;
    
    if ([_session canAddOutput:[self videoDataOutput]])
    {
        Log(@"LMTCaptureVideoPreviewLayerInternal: Added AVCaptureVideoDataOutput to AVCaptureSession");
        [_session addOutput:[self videoDataOutput]];
    }
    else
    {
        Log(@"LMTCaptureVideoPreviewLayerInternal: Can NOT add AVCaptureVideoDataOutput to AVCaptureSession");
        
    }
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutput

- (dispatch_queue_t)videoDataOutputSampleBufferDelegateQueue
{
    if (!_videoDataOutputSampleBufferDelegateQueue)
    {
        // Create a serial dispatch queue used for the sample buffer delegate.
        // In a multi-threaded producer consumer system it's generally a good idea to make sure that producers
        // do not get starved of CPU time by their consumers. In this app we start with VideoDataOutput frames
        // on a high priority queue, and downstream consumers use default priority queues.
        dispatch_queue_t captureOutputSampleBufferDelegateQueue = dispatch_queue_create( "co.coletiv.lightmate.LMTCaptureVideoPreviewLayerInternal.videoDataOutputSampleBufferDelegateQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(captureOutputSampleBufferDelegateQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0));
        
        _videoDataOutputSampleBufferDelegateQueue = captureOutputSampleBufferDelegateQueue;
    }
    
    return _videoDataOutputSampleBufferDelegateQueue;
}

- (AVCaptureVideoDataOutput *)videoDataOutput
{
    if (!_videoDataOutput)
    {
        AVCaptureVideoDataOutput * videoDataOutput = [AVCaptureVideoDataOutput new];
        
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary * videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCMPixelFormat_32BGRA)};
        [videoDataOutput setVideoSettings:videoSettings];
        [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
        
        // Set the video data output delegate
        [videoDataOutput setSampleBufferDelegate:self queue:[self videoDataOutputSampleBufferDelegateQueue]];
        
        // Enable the video data output
        [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        
        _videoDataOutput = videoDataOutput;
    }
    
    return _videoDataOutput;
}

- (void)hijackSessionVideoDataOutput
{
//    if (!_captureOutput)
//    {
//        AVCaptureVideoDataOutput * captureOutput = [AVCaptureVideoDataOutput new];
//        
//        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
//        NSDictionary * videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCMPixelFormat_32BGRA)};
//        [captureOutput setVideoSettings:videoSettings];
//        [captureOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
//        
//        // Set the video data output delegate
//        [captureOutput setSampleBufferDelegate:self queue:[self captureOutputSampleBufferDelegateQueue]];
//        
//        // Enable the video data output
//        [[captureOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
//        
//        _captureOutput = captureOutput;
//    }
//    
//    return _captureOutput;
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    @synchronized (self)
    {
        // Release the buffer if it exists
        if(_videoDataOutputSampleBuffer)
        {
            CFRelease(_videoDataOutputSampleBuffer);
            _videoDataOutputSampleBuffer = NULL;
        }
        
        // Retain
        _videoDataOutputSampleBuffer = sampleBuffer;
        CFRetain(_videoDataOutputSampleBuffer);
    }
}

- (CMSampleBufferRef)sampleBuffer
{
    @synchronized (self)
    {
        return _videoDataOutputSampleBuffer;
    }
}

@end
