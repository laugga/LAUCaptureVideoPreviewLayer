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

#define kVideoDataOutputSampleBuffersSize 2

@interface LMTCaptureVideoPreviewLayerInternal () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession * _session;
    AVCaptureVideoDataOutput * _videoDataOutput;
    dispatch_queue_t _videoDataOutputSampleBufferDelegateQueue;
    
    // Circular array used to keep the sample buffers
    NSUInteger _videoDataOutputSampleBuffersHeadIndex;
    NSUInteger _videoDataOutputSampleBuffersTailIndex;
    CMSampleBufferRef _videoDataOutputSampleBuffers[kVideoDataOutputSampleBuffersSize];
    
    // Hijacked AVCaptureVideoDataOutput (check
    dispatch_queue_t _hijackedVideoDataOutputSampleBufferDelegateQueue;
    id <AVCaptureVideoDataOutputSampleBufferDelegate> _hijackedVideoDataOutputSampleBufferDelegate;
}
@end

@implementation LMTCaptureVideoPreviewLayerInternal

#pragma mark -
#pragma mark AVCaptureSession

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _videoDataOutputSampleBuffersHeadIndex = _videoDataOutputSampleBuffersTailIndex = 0;
        memset(_videoDataOutputSampleBuffers, NULL, kVideoDataOutputSampleBuffersSize);
    }
    return self;
}

- (void)setSession:(AVCaptureSession *)session
{
    if (_session)
    {
        // TODO
    }
    
    _session = session;
    
    // Set the session's AVCaptureVideoDataOutput
    if ([_session canAddOutput:[self videoDataOutput]])
    {
        Log(@"LMTCaptureVideoPreviewLayerInternal: Added AVCaptureVideoDataOutput to AVCaptureSession");
        [_session addOutput:[self videoDataOutput]];
    }
    else
    {
        Log(@"LMTCaptureVideoPreviewLayerInternal: Can NOT add AVCaptureVideoDataOutput to AVCaptureSession");
        [self hijackSessionVideoDataOutput];
    }
}

- (void)hijackSessionVideoDataOutput
{
    Log(@"LMTCaptureVideoPreviewLayerInternal: Hijacking current AVCaptureVideoDataOutput of AVCaptureSession");
    
    if (_session)
    {
        AVCaptureVideoDataOutput * currentVideoDataOutput = nil;
        
        // Look for an instance of AVCaptureVideoDataOutput in session's outputs
        for (AVCaptureOutput * currentOutput in _session.outputs)
        {
            if ([currentOutput isKindOfClass:[AVCaptureVideoDataOutput class]])
            {
                currentVideoDataOutput = (AVCaptureVideoDataOutput *)currentOutput;
                break;
            }
        }
        
        if (currentVideoDataOutput)
        {
            // Copy a reference of current delegate and queue
            _hijackedVideoDataOutputSampleBufferDelegate = currentVideoDataOutput.sampleBufferDelegate;
            _hijackedVideoDataOutputSampleBufferDelegateQueue = currentVideoDataOutput.sampleBufferCallbackQueue;
            
            // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
            NSDictionary * videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCMPixelFormat_32BGRA)};
            [currentVideoDataOutput setVideoSettings:videoSettings];
            [currentVideoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
            
            // Set the video data output delegate
            [currentVideoDataOutput setSampleBufferDelegate:self queue:[self videoDataOutputSampleBufferDelegateQueue]];
            
            // Enable the video data output
            [[currentVideoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        }
        
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
        [self configureVideoDataOutput:videoDataOutput];
        
        _videoDataOutput = videoDataOutput;
    }
    
    return _videoDataOutput;
}

- (void)configureVideoDataOutput:(AVCaptureVideoDataOutput *)videoDataOutput
{
    // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
    NSDictionary * videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey:@(kCMPixelFormat_32BGRA)};
    [videoDataOutput setVideoSettings:videoSettings];
    [videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
    
    // Set the video data output delegate
    [videoDataOutput setSampleBufferDelegate:self queue:[self videoDataOutputSampleBufferDelegateQueue]];
    
    // Enable the video data output
    [[videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
}

#pragma mark -
#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    // Add the sample buffer to the _videoDataOutputSampleBuffers circular array
    [self addVideoDataOutputSampleBuffer:sampleBuffer];
    
    // Was the AVCaptureVideoDataOutput's hijacked?
    if (_hijackedVideoDataOutputSampleBufferDelegate && _hijackedVideoDataOutputSampleBufferDelegateQueue)
    {
        dispatch_async(_hijackedVideoDataOutputSampleBufferDelegateQueue, ^{
            
            // Forward the delegate method to the AVCaptureVideoDataOutput's hijacked sampleBufferDelegate
            if ([_hijackedVideoDataOutputSampleBufferDelegate respondsToSelector:@selector(captureOutput:didOutputSampleBuffer:fromConnection:)])
            {
                [_hijackedVideoDataOutputSampleBufferDelegate captureOutput:captureOutput didOutputSampleBuffer:sampleBuffer fromConnection:connection];
            }
        });
    }
}

#pragma mark -
#pragma mark Ping-pong buffering for videoDataOutputSampleBuffers

- (CMSampleBufferRef)sampleBuffer
{
    @synchronized (self)
    {
        CMSampleBufferRef videoDataOutputSampleBuffer = NULL;
        
        // Check if the circular array is not empty
        if (_videoDataOutputSampleBuffersHeadIndex != _videoDataOutputSampleBuffersTailIndex)
        {
            // Remove an existing sample buffer from the head
            CMSampleBufferRef oldVideoDataOutputSampleBuffer = _videoDataOutputSampleBuffers[_videoDataOutputSampleBuffersHeadIndex];
            
            // Release the buffer if it exists
            if(oldVideoDataOutputSampleBuffer != NULL)
            {
                videoDataOutputSampleBuffer = oldVideoDataOutputSampleBuffer;
            }
            
            // Move head +1
            _videoDataOutputSampleBuffersHeadIndex = (_videoDataOutputSampleBuffersHeadIndex+1)%kVideoDataOutputSampleBuffersSize;
        }
        
        return videoDataOutputSampleBuffer;
    }
}

- (void)addVideoDataOutputSampleBuffer:(CMSampleBufferRef)newVideoDataOutputSampleBuffer
{
    @synchronized (self)
    {
        if (newVideoDataOutputSampleBuffer != NULL)
        {
            // Add the new sample buffer to the tail
            CMSampleBufferRef oldVideoDataOutputSampleBuffer = _videoDataOutputSampleBuffers[_videoDataOutputSampleBuffersTailIndex];
            
            // Release the buffer if it exists
            if(oldVideoDataOutputSampleBuffer != NULL)
            {
                CFRelease(oldVideoDataOutputSampleBuffer);
            }
            
            // Retain
            _videoDataOutputSampleBuffers[_videoDataOutputSampleBuffersTailIndex] = newVideoDataOutputSampleBuffer;
            CFRetain(newVideoDataOutputSampleBuffer);
            
            // Move tail +1
            _videoDataOutputSampleBuffersTailIndex = (_videoDataOutputSampleBuffersTailIndex+1)%kVideoDataOutputSampleBuffersSize;
        }
    }
}

@end
