//
//  FilterCamera.m
//  filter_camera
//
//  Created by vigoss on 2019/9/26.
//

#import "FilterCamera.h"

@interface FilterCamera()<AVCaptureVideoDataOutputSampleBufferDelegate>

@property(nonatomic,strong)     AVCaptureSession                *captureSession;
@property(nonatomic,strong)     AVCaptureVideoDataOutput        *videoOutput;

@property(nonatomic,assign)     AVCaptureDevicePosition         device;


@property(nonatomic,strong)     dispatch_queue_t                videoQueue;

@end

@implementation FilterCamera

- (void)startPreview{
    [self checkAuthWithType:AVMediaTypeAudio completion:^{
        
    }];
    [self checkAuthWithType:AVMediaTypeVideo completion:^{
        [self prepare];
        [self.captureSession startRunning];
    }];
}

- (void)stopPreview{
    [self.captureSession stopRunning];
}

- (instancetype)init{
    self = [super init];
    _device = AVCaptureDevicePositionBack;
    _videoQueue = dispatch_queue_create("com.taobao.filtercamera.queue", nil);
    return self;
}

#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    NSLog(@"captureOutput");
    if (captureOutput == self.videoOutput) {
        if(self.delegate && [self.delegate respondsToSelector:@selector(onBufferOutput:)]){
            [self.delegate onBufferOutput:sampleBuffer];
        }
    }
}


- (BOOL)prepare {
    if (self.captureSession) {
        return NO;
    }
    
    self.captureSession = [[AVCaptureSession alloc] init];
    
    
    [self configureSessionInput];
    
    [self configureSessionOutput];
    
    [self updateVideoOrientation];
    
    return YES;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#pragma clang diagnostic pop
-(void)checkAuthWithType:(AVMediaType)type completion:(void(^)(void))authBlock{
    AVAuthorizationStatus AVstatus = [AVCaptureDevice authorizationStatusForMediaType:type];
    switch (AVstatus) {
            case AVAuthorizationStatusNotDetermined:
        {
            [AVCaptureDevice requestAccessForMediaType:type completionHandler:^(BOOL granted) {
                if (granted) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if(authBlock){
                            authBlock();
                        }
                    });
                }
            }];
        }
            break;
            case  AVAuthorizationStatusRestricted:
            case  AVAuthorizationStatusDenied:
        {
            if(type == AVMediaTypeVideo){
            }
        }
            break;
            case AVAuthorizationStatusAuthorized:
            if(authBlock){
                authBlock();
            }
            break;
        default:
            break;
    }
}

- (void)updateVideoOrientation {
    
    AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;;
    AVCaptureConnection *videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    if ([videoConnection isVideoOrientationSupported]) {
        videoConnection.videoOrientation = videoOrientation;
    }
}

- (NSError *)configureSessionOutput
{
    NSError * error = nil;
    AVCaptureSession * session = self.captureSession;
    [self.captureSession beginConfiguration];
    
    if (self.videoOutput == nil) {
        self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        self.videoOutput.alwaysDiscardsLateVideoFrames = NO;
        [self.videoOutput setSampleBufferDelegate:self queue:self.videoQueue];
        
        [self.videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    }
    
    if (![session.outputs containsObject:self.videoOutput]) {
        if ([session canAddOutput:self.videoOutput]) {
            [session addOutput:self.videoOutput];
        } else {
            if (error == nil) {
                [self.captureSession commitConfiguration];
                return error;
            }
        }
    }
    
    AVCaptureDevice *device = [self videoDeviceForPosition:self.device];
    if ([device lockForConfiguration:&error]) {
        CMTime frameDuration = CMTimeMake(1, 30);
        device.activeVideoMinFrameDuration = frameDuration;
        device.activeVideoMaxFrameDuration = frameDuration;
        [device unlockForConfiguration];
    }
    
    [self.captureSession commitConfiguration];
    return error;
}

- (NSError *)configureSessionInput
{
    [self.captureSession beginConfiguration];
    
    NSError *error = nil;
    
    AVCaptureDevice * device = [self videoDeviceForPosition:self.device];
    
    [self configureDevice:device mediaType:AVMediaTypeVideo error:&error];
    
    if (error) {
        [self.captureSession commitConfiguration];
        return error;
    }
    
    [self.captureSession commitConfiguration];
    
    return error;
}

- (void)configureDevice:(AVCaptureDevice*)newDevice mediaType:(NSString*)mediaType error:(NSError**)error {
    AVCaptureDeviceInput *currentInput = [self currentDeviceInputForMediaType:mediaType];
    AVCaptureDevice *currentUsedDevice = currentInput.device;
    
    if (currentUsedDevice != newDevice) {
        if ([mediaType isEqualToString:AVMediaTypeVideo]) {
            NSError *error;
            if ([newDevice lockForConfiguration:&error]) {
                if (newDevice.isSmoothAutoFocusSupported) {
                    newDevice.smoothAutoFocusEnabled = YES;
                }
                newDevice.subjectAreaChangeMonitoringEnabled = true;
                
                if (newDevice.isLowLightBoostSupported) {
                    newDevice.automaticallyEnablesLowLightBoostWhenAvailable = YES;
                }
                [newDevice unlockForConfiguration];
            } else {
                NSLog(@"Failed to configure device: %@", error);
            }
        }
        
        AVCaptureDeviceInput *newInput = nil;
        
        if (newDevice != nil) {
            newInput = [[AVCaptureDeviceInput alloc] initWithDevice:newDevice error:error];
        }
        
        if (*error == nil) {
            if (currentInput != nil) {
                [self.captureSession removeInput:currentInput];
            }
            
            if (self.device == AVCaptureDevicePositionFront) {
                self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
            }
            else {
                self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
            }
            
            if (newInput != nil) {
                if ([self.captureSession canAddInput:newInput]) {
                    [self.captureSession addInput:newInput];
                    if ([newInput.device hasMediaType:AVMediaTypeVideo]) {
                        AVCaptureConnection *videoConnection = [self videoConnection];
                        if ([videoConnection isVideoStabilizationSupported]) {
                            if ([videoConnection respondsToSelector:@selector(setPreferredVideoStabilizationMode:)]) {
                                videoConnection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeStandard;
                            }
                        }
                    }
                } else {
                }
            }
        }
    }
}

- (AVCaptureConnection*)videoConnection {
    for (AVCaptureConnection * connection in self.videoOutput.connections) {
        for (AVCaptureInputPort * port in connection.inputPorts) {
            if ([port.mediaType isEqual:AVMediaTypeVideo]) {
                return connection;
            }
        }
    }
    
    return nil;
}

- (AVCaptureDevice *)videoDeviceForPosition:(AVCaptureDevicePosition)position {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
#pragma clang diagnostic pop
    
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == (AVCaptureDevicePosition)position) {
            return device;
        }
    }
    
    return nil;
}

- (AVCaptureDeviceInput*)currentDeviceInputForMediaType:(NSString*)mediaType {
    for (AVCaptureDeviceInput* deviceInput in self.captureSession.inputs) {
        if ([deviceInput.device hasMediaType:mediaType]) {
            return deviceInput;
        }
    }
    
    return nil;
}

@end
