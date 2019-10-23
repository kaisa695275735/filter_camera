//
//  TPMCaptureBase.m
//  TPMFramework
//
//  Created by lujunchen on 2017/10/26.
//  Copyright © 2017年 lujun. All rights reserved.
//

#import "TPMCaptureBase.h"
#import "TPMPipeBase.h"
#import "TPMGLContext.h"
#import "TPMGCDContext.h"
#import "TPMMonitor.h"
#import <UIKit/UIKit.h>
#import "TPMTexturePool.h"
#import "IFGLProgram.h"
#import "IFGLUtil.h"
#import <GLKit/GLKit.h>
#import "IFCommonUtil.h"

NSString *const kRGBToBGRFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     highp vec4 color = texture2D(inputImageTexture,textureCoordinate);
     gl_FragColor = vec4(color.b,color.g,color.r,color.a);
 }
 );


@interface TPMCaptureBase()
{
    float                            rotateMatrix[16];
}
@property(nonatomic,strong)NSMutableArray<TPMCaptureVideoDataDelegate> * videoTargets;
@property(nonatomic,strong)NSMutableArray<TPMCaptureAudioDataDelegate> * audioTargets;
@property(nonatomic,strong)NSMutableArray<TPMCaptureVideoDataDelegate> * imageTargets;

@property(nonatomic,strong)     IFGLProgram                    *nv12ToRGBProgram;
@property(nonatomic,strong)     IFGLProgram                    *bgrToRgbProgram;
@property(nonatomic,strong)     IFGLProgram                    *customProgram;
@property(nonatomic,assign)     GLuint                          frameBuffer;
@property(nonatomic,assign)     CVOpenGLESTextureRef            rgbaTextureRef;
@property(nonatomic,assign)     CVOpenGLESTextureRef            luminanceTextureRef;
@property(nonatomic,assign)     CVOpenGLESTextureRef            chromaTextureRef;
@property(nonatomic,assign)     CVOpenGLESTextureCacheRef       videoTextureCache;
@property(nonatomic,assign)     GLuint                          textureID;


@property(nonatomic,assign)     GLuint                          textureUniformY;
@property(nonatomic,assign)     GLuint                          textureUniformUV;

@end

@implementation TPMCaptureBase

@synthesize runState;

- (instancetype)init
{
    if (self = [super init]) {
        self.runState = TPMRunStateNone;
    }
    return self;
}

- (instancetype)initWithConfig:(TPMCaptureConfig *)config{
    return [self init];
}

- (void)start:(TPMComplectionBlock)completion{}

- (void)end:(TPMComplectionBlock)completion{}

- (void)pause:(TPMComplectionBlock)completion{}

- (void)resume:(TPMComplectionBlock)completion{}

- (NSMutableArray <TPMCaptureVideoDataDelegate>*)videoTargets
{
    if (!_videoTargets)
    {
        _videoTargets = [[NSMutableArray<TPMCaptureVideoDataDelegate> alloc] init];
    }
    return _videoTargets;
}

- (NSMutableArray <TPMCaptureAudioDataDelegate>*)audioTargets
{
    if (!_audioTargets)
    {
        _audioTargets = [[NSMutableArray<TPMCaptureAudioDataDelegate> alloc] init];
    }
    return _audioTargets;
}

- (NSMutableArray <TPMCaptureVideoDataDelegate>*)imageTargets
{
    if (!_imageTargets)
    {
        _imageTargets = [[NSMutableArray<TPMCaptureVideoDataDelegate> alloc] init];
    }
    return _imageTargets;
}

- (void)addVideoTarget:(id<TPMCaptureVideoDataDelegate>)target
{
    [self.videoTargets addObject:target];
}

- (void)addAudioTarget:(id<TPMCaptureAudioDataDelegate>)target
{
    [self.audioTargets addObject:target];
}

- (void)addStillImageTarget:(id<TPMCaptureVideoDataDelegate>)target
{
    [self.imageTargets addObject:target];
}

- (void)onTargetStateChange:(TPMRunState)state tartet:(id)target;
{
    switch (state) {
        case TPMRunStatePaused:
        {
            BOOL allPaused = [self isAllInState:TPMRunStatePaused exceptTarget:target];
            
            if (allPaused) {
                [self pause:^(NSError *error) {
                    [self updateTargetState:TPMRunStatePaused];
                }];
            }
        }
            break;
        case TPMRunStateStarted:
        {
            if (self.runState == TPMRunStatePaused) {
                [self resume:^(NSError *error) {
                    [self updateTargetState:TPMRunStateStarted];
                }];
            }
            else if(self.runState == TPMRunStateNone)
            {
                [self start:^(NSError *error) {
                    [self updateTargetState:TPMRunStateStarted];
                }];
            }
        }
            break;
        case TPMRunStateEnded:
        {
            BOOL hasEnded = [self isAllInState:TPMRunStateEnded exceptTarget:target];
            
            if (hasEnded) {
                [self end:^(NSError *error) {
                    void(^block)(void) = ^(void){
                        [TPMGLContext usePipeContext];
                        
                        [self updateTargetState:TPMRunStateEnded];
                        [self.videoTargets removeAllObjects];
                        [self.audioTargets removeAllObjects];
                        [self.imageTargets removeAllObjects];
                        if (self.videoTextureCache) {
                            CFRelease(self.videoTextureCache);
                            self.videoTextureCache = nil;
                        }
                        if (self.textureID != 0) {
                            GLuint texID = self.textureID;
                            glDeleteTextures(1, &texID);
                            self.textureID = 0;
                        }
                        if (self.frameBuffer != 0) {
                            GLuint frameBuffer = self.frameBuffer;
                            glDeleteFramebuffers(1, &frameBuffer);
                            self.frameBuffer = 0;
                        }
                    };
                    TPM_gcd_safe_async_in_pipeQ(block);
                }];
            }
        }
            break;
        default:
            break;
    }
}

- (void)captureImage:(TPMComplectionBlock)completion
{
    if (completion) {
        completion(nil);
    }
}

- (BOOL)isAllInState:(TPMRunState)state exceptTarget:(id)target
{
    BOOL allInState = YES;
    for (id<TPMCaptureVideoDataDelegate> videoTarget in self.videoTargets ) {
        TPMRunState curState = [videoTarget getTargetState];
        if (curState != state && curState != TPMRunStateNone && videoTarget != target) {
            allInState = NO;
            break;
        }
    }
    for (id<TPMCaptureAudioDataDelegate> audioTarget in self.audioTargets) {
        TPMRunState curState = [audioTarget getTargetState];
        if (curState != state && curState != TPMRunStateNone && audioTarget != target) {
            allInState = NO;
            break;
        }
    }
    //图片管道有问题，需要考虑实现方式。
    for (id<TPMCaptureAudioDataDelegate> imageTarget in self.imageTargets) {
        if ([imageTarget getTargetState] != state && imageTarget != target) {
            allInState = NO;
            break;
        }
    }
    return allInState;
}

- (void)updateTargetState:(TPMRunState)state
{
    self.runState = state;
    for (id<TPMCaptureVideoDataDelegate> videoTarget in self.videoTargets) {
        [videoTarget onCaptureStateChangeCompletion:state];
    }
    for (id<TPMCaptureAudioDataDelegate> audioTarget in self.audioTargets) {
        [audioTarget onCaptureStateChangeCompletion:state];
    }
    for (id<TPMCaptureAudioDataDelegate> imageTarget in self.imageTargets) {
        [imageTarget onCaptureStateChangeCompletion:state];
    }
}


- (void)removeTarget:(id)target
{
    [self.audioTargets removeObject:target];
    [self.videoTargets removeObject:target];
    [self.imageTargets removeObject:target];
    if (self.audioTargets.count == 0 && self.videoTargets.count == 0 && self.imageTargets.count == 0) {
        [self end:^(NSError *error) {
            self.runState = TPMRunStateNone;
        }];
    }
}
//子类图像采集完成，调用该方法完成回调。
- (void)onImageCaptureFinishedWithCGImage:(CGImageRef)imageRef extraParam:(NSMutableDictionary*)param{
    TPMCGImageRetain(imageRef);
    void(^block)(void) = ^(void){
        
        [TPMGLContext usePipeContext];
        
        size_t width = CGImageGetWidth(imageRef);
        size_t height = CGImageGetHeight(imageRef);
        
        TPMTexture * texture = [TPMTexturePool createTPMTextureWith:width andHeight:height];
        
        if (texture) {
            [IFGLUtil convertCGImage:imageRef toTexture:texture.textureID inSize:CGSizeMake(width, height)];
            
            for (id<TPMCaptureVideoDataDelegate> object in self.imageTargets)
            {
                [object captureDataOutputWithSampleBuffer:NULL texture:texture extraParam:param];
            }
            TPMTextureRelease(texture);
        }

        TPMCGImageRelease(imageRef);
    };
    TPM_gcd_safe_async_in_pipeQ(block);
}

- (void)onImageCaptureFinishedWithSampleBuffer:(CMSampleBufferRef)bufferRef extraParam:(NSMutableDictionary *)param
{
    TPMSampleBufferRetain(bufferRef);
    void(^block)(void) = ^(void){
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(bufferRef);
        
        [TPMGLContext usePipeContext];
        
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        
        TPMTexture * texture = [TPMTexturePool createTPMTextureWith:width andHeight:height];
        
        if (texture) {
            [self renderPixelBuffer:pixelBuffer toTexture:texture transform:CGAffineTransformIdentity];
            
            for (id<TPMCaptureVideoDataDelegate> object in self.imageTargets)
            {
                [object captureDataOutputWithSampleBuffer:bufferRef texture:texture extraParam:param];
            }
            TPMTextureRelease(texture);
        }
        TPMSampleBufferRlease(bufferRef);
    };
    TPM_gcd_safe_async_in_pipeQ(block);
}

- (void)onVideoCaptureFinishedWithSampleBuffer:(CMSampleBufferRef)bufferRef extraParam:(NSMutableDictionary*)param
{
    TPMSampleBufferRetain(bufferRef);
    void(^block)(void) = ^(void){
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(bufferRef);
        
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        
        [TPMGLContext usePipeContext];
        CGAffineTransform transform = CGAffineTransformIdentity;
        if ([param objectForKey:@"kCaptureVideoTransform"]) {
            transform = [param[@"kCaptureVideoTransform"] CGAffineTransformValue];
            CGSize newSize = [IFCommonUtil rotateSize:CGSizeMake(width, height) transform:transform];
            width = newSize.width;
            height = newSize.height;
        }
        
        TPMTexture * texture = [TPMTexturePool createTPMTextureWith:width andHeight:height];
        
        if (texture) {
            [self renderPixelBuffer:pixelBuffer toTexture:texture transform:transform];
            
            for (id<TPMCaptureVideoDataDelegate> object in self.videoTargets)
            {
                [object captureDataOutputWithSampleBuffer:bufferRef texture:texture extraParam:param];
            }
            TPMTextureRelease(texture);
        }
        TPMSampleBufferRlease(bufferRef);

    };
    if(param[@"kParamNeedSync"]){
        dispatch_sync(PipeQueue,block);
    }
    else{
        dispatch_async(PipeQueue,block);
    }
}

- (void)onAudioCaptureFinishedWithSampleBuffer:(CMSampleBufferRef)bufferRef
{
    CFRetain(bufferRef);
    TPM_gcd_safe_sync_in_pipeQ(^(){
        for (id<TPMCaptureAudioDataDelegate> object in self.audioTargets)
        {
            [object captureDataOutputWithBuffer:bufferRef];
        }
        CFRelease(bufferRef);
    });
}

#pragma mark get method
- (IFGLProgram *)nv12ToRGBProgram
{
    if (!_nv12ToRGBProgram) {
        _nv12ToRGBProgram = [[IFGLProgram alloc] initWithVertexShaderString:kIFGLRotateVertexShaderString fragmentShaderString:kIFGLNV12TORGBFragmentShaderString];
        self.textureUniformY = [_nv12ToRGBProgram uniformIndex:@"inputImageTextureY"];
        self.textureUniformUV = [_nv12ToRGBProgram uniformIndex:@"inputImageTextureUV"];
    }
    return _nv12ToRGBProgram;
}

- (IFGLProgram *)bgrToRgbProgram
{
    if (!_bgrToRgbProgram) {
        _bgrToRgbProgram = [[IFGLProgram alloc] initWithVertexShaderString:kIFGLRotateVertexShaderString fragmentShaderString:kRGBToBGRFragmentShaderString];
    }
    return _bgrToRgbProgram;
}

- (IFGLProgram *)customProgram
{
    if (!_customProgram) {
        _customProgram = [[IFGLProgram alloc] initWithVertexShaderString:kIFGLRotateVertexShaderString fragmentShaderString:kIFGLGeneralFragmentShaderString];
    }
    return _customProgram;
}

#pragma mark privite method
- (void)updateRotate:(CGAffineTransform)transform
{
//    CGAffineTransform newTransform = CGAffineTransformInvert(transform);
    rotateMatrix[0] = transform.a;
    rotateMatrix[1] = transform.b;
    rotateMatrix[4] = transform.c;
    rotateMatrix[5] = transform.d;
    rotateMatrix[10] = 1.0;
    rotateMatrix[15] = 1.0;
}

- (void)updateTextureWithWidth:(size_t)width andHeight:(size_t)height buf:(unsigned char *)buffer type:(int)type texture:(GLuint)texture
{
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, type, (int)width, (int)height, 0, type, GL_UNSIGNED_BYTE, buffer);
    glBindTexture(GL_TEXTURE_2D, 0);
}

bool isNV12(OSType pixelFormat){
    return pixelFormat == kCVPixelFormatType_420YpCbCr8PlanarFullRange||
    pixelFormat == kCVPixelFormatType_420YpCbCr8Planar||
    pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange||
    pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
}
bool isBGR(OSType pixelFormat){
    return pixelFormat == kCVPixelFormatType_32BGRA;
}
- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer toTexture:(TPMTexture *)texture transform:(CGAffineTransform)transform
{
    if (self.videoTextureCache == nil) {
        self.videoTextureCache = [IFGLUtil createVideoTextureCache:[TPMGLContext pipeContext]];
    }
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    if (!CGAffineTransformIsIdentity(transform)) {
        CGSize newSize = [IFCommonUtil rotateSize:CGSizeMake(width, height) transform:transform];
        width = newSize.width;
        height = newSize.height;
    }
    
    [self updateRotate:transform];

    OSType pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, texture.frameBuffer);
    glViewport(0, 0, (int)width, (int)height);

    IFGLProgram * curProgram = self.nv12ToRGBProgram;
    if (isBGR(pixelFormat)) {
        curProgram = self.bgrToRgbProgram;
    }
    [curProgram use];
    glVertexAttribPointer(curProgram.positionAttributeLocation, 2, GL_FLOAT, 0, 0, generalVertices);
    glEnableVertexAttribArray(curProgram.positionAttributeLocation);
    
    glVertexAttribPointer(curProgram.texCoordAttributeLocation, 2, GL_FLOAT, 0, 0,textureGeneralTexCoord);
    glEnableVertexAttribArray(curProgram.texCoordAttributeLocation);

    if (isNV12(pixelFormat)) {
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, [self createLuminanceTexture:pixelBuffer]);
        glUniform1i(self.textureUniformY, 2);
        
        glActiveTexture(GL_TEXTURE3);
        glBindTexture(GL_TEXTURE_2D, [self createChromaTexture:pixelBuffer]);
        glUniform1i(self.textureUniformUV, 3);
    }else if(isBGR(pixelFormat)){
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, [self createRGBATexture:pixelBuffer]);
        glUniform1i(curProgram.textureUniform, 0);
    }
    
    glUniformMatrix4fv([curProgram uniformIndex:@"rotateMatrix"], 1, GL_FALSE, rotateMatrix);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFlush();

    if (self.chromaTextureRef)
    {
        CFRelease(self.chromaTextureRef);
        self.chromaTextureRef = NULL;
    }
    
    if (self.luminanceTextureRef) {
        CFRelease(self.luminanceTextureRef);
        self.luminanceTextureRef = NULL;
    }
    
    if (self.rgbaTextureRef)
    {
        CFRelease(self.rgbaTextureRef);
        self.rgbaTextureRef = NULL;
    }

    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
}

- (GLuint)createLuminanceTexture:(CVPixelBufferRef)inputPixelBuffer
{
    CVReturn err = 0;
    NSUInteger width = CVPixelBufferGetWidth(inputPixelBuffer);
    NSUInteger height = CVPixelBufferGetHeight(inputPixelBuffer);
    CVOpenGLESTextureRef textureRef;
    err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault,
                                                        self.videoTextureCache,
                                                        inputPixelBuffer,
                                                        NULL, // texture attributes
                                                        GL_TEXTURE_2D,
                                                        GL_LUMINANCE, // opengl format
                                                        (int)width,
                                                        (int)height,
                                                        GL_LUMINANCE, // native iOS format
                                                        GL_UNSIGNED_BYTE,
                                                        0,
                                                        &textureRef);
    if (err)
    {
        NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    self.luminanceTextureRef = textureRef;
    glBindTexture(CVOpenGLESTextureGetTarget(self.luminanceTextureRef), CVOpenGLESTextureGetName(self.luminanceTextureRef));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    GLuint texture =  CVOpenGLESTextureGetName(self.luminanceTextureRef);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return texture;
}

- (GLuint)createChromaTexture:(CVPixelBufferRef)inputPixelBuffer
{
    CVReturn err = 0;
    NSUInteger width = CVPixelBufferGetWidth(inputPixelBuffer);
    NSUInteger height = CVPixelBufferGetHeight(inputPixelBuffer);
    CVOpenGLESTextureRef textureRef;
    err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault,
                                                        self.videoTextureCache,
                                                        inputPixelBuffer,
                                                        NULL, // texture attributes
                                                        GL_TEXTURE_2D,
                                                        GL_LUMINANCE_ALPHA, // opengl format
                                                        (int)width/2,
                                                        (int)height/2,
                                                        GL_LUMINANCE_ALPHA, // native iOS format
                                                        GL_UNSIGNED_BYTE,
                                                        1,
                                                        &textureRef);
    if (err)
    {
        NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    self.chromaTextureRef = textureRef;
    glBindTexture(CVOpenGLESTextureGetTarget(self.chromaTextureRef), CVOpenGLESTextureGetName(self.chromaTextureRef));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    GLuint texture =  CVOpenGLESTextureGetName(self.chromaTextureRef);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return texture;
}

- (GLuint)createRGBATexture:(CVPixelBufferRef)inputPixelBuffer
{
    CVReturn err = 0;
    NSUInteger width = CVPixelBufferGetWidth(inputPixelBuffer);
    NSUInteger height = CVPixelBufferGetHeight(inputPixelBuffer);
    CVOpenGLESTextureRef textureRef;
    err = CVOpenGLESTextureCacheCreateTextureFromImage (kCFAllocatorDefault,
                                                        self.videoTextureCache,
                                                        inputPixelBuffer,
                                                        NULL, // texture attributes
                                                        GL_TEXTURE_2D,
                                                        GL_RGBA, // opengl format
                                                        (int)width,
                                                        (int)height,
                                                        GL_RGBA, // native iOS format
                                                        GL_UNSIGNED_BYTE,
                                                        0,
                                                        &textureRef);
    if (err)
    {
        NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
    }
    self.rgbaTextureRef = textureRef;
    glBindTexture(CVOpenGLESTextureGetTarget(self.rgbaTextureRef), CVOpenGLESTextureGetName(self.rgbaTextureRef));
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    GLuint texture =  CVOpenGLESTextureGetName(self.rgbaTextureRef);
    
    glBindTexture(GL_TEXTURE_2D, 0);
    
    return texture;
}

- (void)dealloc
{
    TPMInfo(@"capture dealloc");
}

@end
