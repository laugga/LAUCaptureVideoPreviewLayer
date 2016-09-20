/*
 
 PreviewViewController.m
 LMTCaptureVideoPreviewLayer UI Tests Application
 
 Copyright (c) 2016 Luis Laugga
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

#import "PreviewViewController.h"

@interface PreviewViewController ()

@end

@implementation PreviewViewController

#pragma mark -
#pragma mark Initialization

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if(self)
    {
        // AVCaptureSession queue
        _sessionQueue = dispatch_queue_create( "com.laugga.lightmate.sessionQueue", DISPATCH_QUEUE_SERIAL);
        
    }
    return self;
}

#pragma mark -
#pragma mark View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Camera Preview View
    [self.view addSubview:[self previewView]];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self previewView].frame = self.view.bounds;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    dispatch_sync(_sessionQueue, ^{
        [self setupCaptureSession];
    });
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [_session startRunning];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [_session stopRunning];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    PrettyLog;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    PrettyLog;
}

#pragma mark -
#pragma mark Preview View

- (PreviewView *)previewView
{
    // Check if the preview view is already initialized
    if (_previewView == nil)
    {
        _previewView = [[PreviewView alloc] initWithFrame:CGRectZero];
    }
    
    return _previewView;
}

#pragma mark -
#pragma mark AVCaptureSession

- (void)setupCaptureSession
{
    if (_session != nil)
    {
        return;
    }

#if !TARGET_OS_SIMULATOR
    
    // Create Session
    _session = [AVCaptureSession new];

    // Pick Framerate and Session Preset
    NSString * sessionPreset = AVCaptureSessionPresetPhoto; // Use high preset
    
    // For single core systems like iPhone 4 and iPod Touch 4th Generation we use a lower resolution and framerate to maintain real-time performance.
    if ([NSProcessInfo processInfo].processorCount == 1)
    {
        if ([_session canSetSessionPreset:AVCaptureSessionPreset640x480])
        {
            sessionPreset = AVCaptureSessionPreset640x480;
        }
    }
    else
    {
        // When using the CPU renderers or the CoreImage renderer we lower the resolution to 720p so that all devices can maintain real-time performance (this is primarily for A5 based devices like iPhone 4s and iPod Touch 5th Generation).
        if ([_session canSetSessionPreset:AVCaptureSessionPreset1280x720])
        {
            sessionPreset = AVCaptureSessionPreset1280x720;
        }
    }
    
    // Assign capture session
    _session.sessionPreset = sessionPreset;
    
    // Select a video device, make an input
    NSInteger desiredPosition = AVCaptureDevicePositionBack;
    
    AVCaptureDevice * captureDevice = [self captureDeviceForPosition:desiredPosition];
    [self setCaptureDevice:captureDevice];
    
    NSError * error = nil;
    AVCaptureDeviceInput * deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_device error:&error];
    
    // Check for error
    if (error)
    {
        [self teardownCaptureSession];
        return; // stop
    }
    
    // Add device input to session
    if ([_session canAddInput:deviceInput])
    {
        [_session addInput:deviceInput];
    }
    else
    {
        [self teardownCaptureSession];
        return; // stop
    }
    
    // Observe for specific notifications related with the session
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionNotification:) name:nil object:_session];
    
#endif
    
    // Setup camera preview
    [_previewView setCaptureSession:_session];
}

- (void)teardownCaptureSession
{
    if (_session)
    {
        // Teardown preview view
        [_previewView setCaptureSession:nil];
        
        // Release device
        [self setCaptureDevice:nil];
        
        // Release session
        _session = nil;
    }
}

- (AVCaptureDevice *)captureDeviceForPosition:(AVCaptureDevicePosition)desiredPosition {
    
    for (AVCaptureDevice * captureDevice in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo])
    {
        if ([captureDevice position] == desiredPosition)
        {
            //            NSError * error = nil;
            //
            //            // Calculate frame duration
            //            CMTime frameDuration = kCMTimeInvalid;
            //            frameDuration = CMTimeMake(1, _frameRate);
            //
            //            if ([captureDevice lockForConfiguration:&error])
            //            {
            //                captureDevice.activeVideoMaxFrameDuration = frameDuration;
            //                captureDevice.activeVideoMinFrameDuration = frameDuration;
            //                [captureDevice unlockForConfiguration];
            //            }
            //            else
            //            {
            //                Log(@"Camera: videoDevice lockForConfiguration returned error %@", error);
            //            }
            
            return captureDevice;
        }
    }
    
    return nil;
}

- (void)setCaptureDevice:(AVCaptureDevice *)captureDevice
{
    //    if (_device) {
    //
    //        // Remove observer from capture device
    //        [_device removeObserver:self forKeyPath:kCameraCaptureDeviceAdjustingFocus];
    //        [_device removeObserver:self forKeyPath:kCameraCaptureDeviceAdjustingExposure];
    //    }
    //
    //    if (captureDevice) {
    //
    //        // Add Observer to capture device for focus and exposure events
    //        [captureDevice addObserver:self forKeyPath:kCameraCaptureDeviceAdjustingFocus options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:NULL];
    //        [captureDevice addObserver:self forKeyPath:kCameraCaptureDeviceAdjustingExposure options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld) context:NULL];
    //    }
    
    _device = captureDevice;
}

#pragma mark -
#pragma mark Actions

#pragma mark -
#pragma mark AVCaptureSession Notifications

- (void)captureSessionNotification:(NSNotification *)notification
{
    dispatch_async(_sessionQueue, ^{
        
        if ([notification.name isEqualToString:AVCaptureSessionWasInterruptedNotification])
        {
            Log(@"Camera: AVCaptureSessionWasInterruptedNotification");
            
            // Do something
        }
        else if ([notification.name isEqualToString:AVCaptureSessionInterruptionEndedNotification])
        {
            Log(@"Camera: AVCaptureSessionInterruptionEndedNotification");
            
            // Do something
        }
        else if ([notification.name isEqualToString:AVCaptureSessionRuntimeErrorNotification])
        {
            Log(@"Camera: AVCaptureSessionRuntimeErrorNotification");
            
            // Do something
        }
        else if ([notification.name isEqualToString:AVCaptureSessionDidStartRunningNotification])
        {
            Log(@"Camera: AVCaptureSessionDidStartRunningNotification");
            
            // ...
        }
        else if ([notification.name isEqualToString:AVCaptureSessionDidStopRunningNotification])
        {
            Log(@"Camera: AVCaptureSessionDidStopRunningNotification");
            
            // ...
        }
    });
}

@end
