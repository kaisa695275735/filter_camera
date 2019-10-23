//
//  FilterTexture1.m
//  filter_camera
//
//  Created by vigoss on 2019/9/26.
//

#import "FilterTexture2.h"

#import <OpenGLES/ES3/gl.h>

#import "IFGLProgram.h"
#import "IFGLUtil.h"
#import "IFCommon.h"

@interface FilterTexture2()<FilterCameraDelegate>


@property(assign,nonatomic) CVPixelBufferRef        pixelBuffer;
@property(strong,nonatomic) NSMutableArray          *bufferQueue;
@property(nonatomic,strong) NSObject<FlutterTextureRegistry>                    *registry;


@property(nonatomic,assign)     CVOpenGLESTextureRef            luminanceTextureRef;
@property(nonatomic,assign)     CVOpenGLESTextureRef            chromaTextureRef;
@property(nonatomic,assign)     CVOpenGLESTextureCacheRef       videoTextureCache;
@property(nonatomic,strong)     IFGLProgram                     *nv12ToRGBProgram;
@property(nonatomic,assign)     GLuint                          textureUniformY;
@property(nonatomic,assign)     GLuint                          textureUniformUV;

@property(nonatomic,assign)     GLuint                          frameBuffer;

@property(nonatomic,assign)     GLuint                          targetTexture;

@property(nonatomic,assign)     GLuint                          count;

@end

@implementation FilterTexture2
- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry> *)registry{
    self = [super init];
    self.filterCamera = [FilterCamera new];
    self.filterCamera.delegate = self;
    [self.filterCamera startPreview];
    self.bufferQueue = [NSMutableArray new];
    self.registry = registry;
    return self;
}

- (void)onBufferOutput:(CMSampleBufferRef)buffer{
    @synchronized (self) {
        dispatch_sync(self.glQueue, ^{
            [EAGLContext setCurrentContext:self.glContext];
            
            CVPixelBufferRef newBuffer = CMSampleBufferGetImageBuffer(buffer);
            
            size_t width = CVPixelBufferGetWidth(newBuffer);
            size_t height = CVPixelBufferGetHeight(newBuffer);
            
            if(self.targetTexture == 0){
                self.targetTexture = [IFGLUtil createTextureWithWidth:width andHeight:height];
            }
            
            [self renderPixelBuffer:newBuffer toTexture:self.targetTexture];
            
            [self.registry textureFrameAvailable:self.textureId];
        });
    }
}

- (GLuint)copyShareTexture{
    return self.targetTexture;
}


- (void)renderPixelBuffer:(CVPixelBufferRef)pixelBuffer toTexture:(GLuint)texture
{
    if (self.videoTextureCache == nil) {
        self.videoTextureCache = [IFGLUtil createVideoTextureCache:self.glContext];
    }
    if(self.frameBuffer == 0){
        self.frameBuffer = [IFGLUtil createFrameBuffer];
    }
    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    glViewport(0, 0, (int)width, (int)height);
    
    IFGLProgram * curProgram = self.nv12ToRGBProgram;
    
    [curProgram use];
    
    glVertexAttribPointer(curProgram.positionAttributeLocation, 2, GL_FLOAT, 0, 0, generalVertices);
    glEnableVertexAttribArray(curProgram.positionAttributeLocation);
    
    glVertexAttribPointer(curProgram.texCoordAttributeLocation, 2, GL_FLOAT, 0, 0, textureMirrorTexCoord);
    glEnableVertexAttribArray(curProgram.texCoordAttributeLocation);
    
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, [self createLuminanceTexture:pixelBuffer]);
    glUniform1i(self.textureUniformY, 2);
    
    glActiveTexture(GL_TEXTURE3);
    glBindTexture(GL_TEXTURE_2D, [self createChromaTexture:pixelBuffer]);
    glUniform1i(self.textureUniformUV, 3);
    
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
    
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
}

#pragma mark Method
- (IFGLProgram *)nv12ToRGBProgram
{
    if (!_nv12ToRGBProgram) {
        _nv12ToRGBProgram = [[IFGLProgram alloc] initWithVertexShaderString:kIFGLGeneralVertexShaderString fragmentShaderString:kIFGLNV12TORGBFragmentShaderString];
        self.textureUniformY = [_nv12ToRGBProgram uniformIndex:@"inputImageTextureY"];
        self.textureUniformUV = [_nv12ToRGBProgram uniformIndex:@"inputImageTextureUV"];
    }
    return _nv12ToRGBProgram;
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
@end
