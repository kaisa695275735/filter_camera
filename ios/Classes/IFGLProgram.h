//
//  IFGLProgram.h
//  ifcommon
//
//  Created by lujunchen on 2019/2/28.
//

#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define SHADER_STRING(text) @#text

NS_ASSUME_NONNULL_BEGIN

@interface IFGLProgram : NSObject

@property(nonatomic,assign)GLuint              positionAttributeLocation;
@property(nonatomic,assign)GLuint              texCoordAttributeLocation;
@property(nonatomic,assign)GLuint              textureUniform;

- (instancetype)initWithVertexShaderString:(NSString *)vShaderString
                      fragmentShaderString:(NSString *)fShaderString;
- (void)addAttribute:(NSString *)attributeName;
- (GLuint)attributeIndex:(NSString *)attributeName;
- (GLuint)uniformIndex:(NSString *)uniformName;
- (void)use;
@end

NS_ASSUME_NONNULL_END
