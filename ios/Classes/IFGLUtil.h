//
//  IFGLUtil.h
//  ifcommon
//
//  Created by lujunchen on 2019/2/28.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface IFGLUtil : NSObject

+ (void)updateTextureWithWidth:(size_t)width andHeight:(size_t)height textureID:(GLuint)textureID;
+ (GLuint)createTextureWithWidth:(size_t)width andHeight:(size_t)height;
+ (void)convertCGImage:(CGImageRef)image toTexture:(GLuint)textureID;
+ (void)convertCGImage:(CGImageRef)image toTexture:(GLuint)textureID inSize:(CGSize)size;
+ (GLuint)createFrameBuffer;
+ (CVOpenGLESTextureCacheRef)createVideoTextureCache:(EAGLContext *)context;
+ (CVPixelBufferRef)createPixelBufferFromImage:(CGImageRef)image;
+ (UIImage *)testReadGpu:(GLfloat)width height:(GLfloat)height;
@end

NS_ASSUME_NONNULL_END
