//
//  IFGLProgram.m
//  ifcommon
//
//  Created by lujunchen on 2019/2/28.
//

#import "IFGLProgram.h"

NSString *const kIFGLNV12TORGBFragmentShaderString = SHADER_STRING
(
 precision mediump float;
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTextureY;
 uniform sampler2D inputImageTextureUV;
 
 const vec3 matYUVRGB1 = vec3(1.0,0.0,1.402);
 const vec3 matYUVRGB2 = vec3(1.0,-0.344,-0.714);
 const vec3 matYUVRGB3 = vec3(1.0,1.772,0.0);
 
 const vec3 delyuv = vec3(-0.0/255.0,-128.0/255.0,-128.0/255.0);
 
 void main()
 {
     mediump vec3 yuv;
     vec3 CurResult;
     
     yuv.r = texture2D(inputImageTextureY,textureCoordinate).r;
     yuv.g = texture2D(inputImageTextureUV,textureCoordinate).r;
     yuv.b = texture2D(inputImageTextureUV,textureCoordinate).a;
     
     yuv += delyuv;
     
     CurResult.x = dot(yuv,matYUVRGB1);
     CurResult.y = dot(yuv,matYUVRGB2);
     CurResult.z = dot(yuv,matYUVRGB3);
     
     gl_FragColor = vec4(CurResult,1);
 }
 );
NSString *const kIFGLRotateVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 uniform mat4 rotateMatrix;
 
 void main()
 {
     gl_Position = rotateMatrix * position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );

NSString *const kTestGeneralFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = vec4(1.0,0.0,1.0,1.0);
 }
 );


NSString *const kIFGLGeneralVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 varying vec2 textureCoordinate;
 
 void main()
 {
     gl_Position = position;
     textureCoordinate = inputTextureCoordinate.xy;
 }
 );


NSString *const kIFGLGeneralFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     gl_FragColor = texture2D(inputImageTexture,textureCoordinate);
 }
 );

const GLfloat generalVertices[] = {
    -1.0f, -1.0f,
    -1.0f, 1.0f,
    1.0f,  -1.0f,
    1.0f,  1.0f,
};

const GLfloat screenGeneralTexcoord[] = {
    0.0f, 1.0f,
    0.0f, 0.0f,
    1.0f, 1.0f,
    1.0f, 0.0f,
};

const GLfloat screenMirrorTexcoord[] = {
    1.0f, 1.0f,
    1.0f, 0.0f,
    0.0f, 1.0f,
    0.0f, 0.0f,
};


const GLfloat textureGeneralTexCoord[] = {
    0.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 0.0f,
    1.0f, 1.0f,
};

const GLfloat textureMirrorTexCoord[] = {
    1.0f, 0.0f,
    1.0f, 1.0f,
    0.0f, 0.0f,
    0.0f, 1.0f,
};

@interface IFGLProgram()

@property(nonatomic,strong) NSMutableArray                              *attributes;
@property(nonatomic,strong) NSMutableDictionary<NSString*, NSNumber*>   *uniforms;
@property(nonatomic,assign) GLuint                                      program;
@property(nonatomic,assign) GLuint                                      vertShader;
@property(nonatomic,assign) GLuint                                      fragShader;

@end

@implementation IFGLProgram

- (instancetype)init
{
    if (self = [self initWithVertexShaderString:kIFGLGeneralVertexShaderString fragmentShaderString:kIFGLGeneralFragmentShaderString]) {
        self.textureUniform = [self uniformIndex:@"inputImageTexture"];
    }
    return self;
}

- (instancetype)initWithVertexShaderString:(NSString *)vShaderString
                      fragmentShaderString:(NSString *)fShaderString;
{
    
    if ((self = [super init]))
    {
        
        self.attributes = [[NSMutableArray alloc] init];
        self.uniforms = [[NSMutableDictionary alloc] init];
        self.program = glCreateProgram();
        
        if (![self compileShader:&_vertShader
                            type:GL_VERTEX_SHADER
                          string:vShaderString])
        {
            NSLog(@"FMAVEffect FMAVEffectGLProgram Failed to compile vertex shader");
        }
        
        if (![self compileShader:&_fragShader
                            type:GL_FRAGMENT_SHADER
                          string:fShaderString])
        {
            NSLog(@"FMAVEffect FMAVEffectGLProgram Failed to compile fragment shader");
        }
        
        
        glAttachShader(self.program, _vertShader);
        glAttachShader(self.program, _fragShader);
        
        //called before program link
        [self addAttribute:@"position"];
        [self addAttribute:@"inputTextureCoordinate"];
        
        if (![self link]) {
            NSLog(@"FMAVEffect FMAVEffectGLProgram link failed");
        }
        // 4
        self.positionAttributeLocation = [self attributeIndex:@"position"];
        self.texCoordAttributeLocation = [self attributeIndex:@"inputTextureCoordinate"];
    }
    
    return self;
}

- (BOOL)compileShader:(GLuint *)shader
                 type:(GLenum)type
               string:(NSString *)shaderString
{
    GLint status;
    const GLchar *source;
    
    source =
    (GLchar *)[shaderString UTF8String];
    if (!source)
    {
        NSLog(@"FMAVEffect FMAVEffectGLProgram Failed to load shader source");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    
    if (status != GL_TRUE)
    {
        GLint logLength;
        glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength > 0)
        {
            GLchar *log = (GLchar *)malloc(logLength);
            glGetShaderInfoLog(*shader, logLength, &logLength, log);
            if (shader == &_vertShader)
            {
                NSLog(@"FMAVEffect FMAVEffectGLProgram compile vertext shader error: %s", log);
            }
            else
            {
                NSLog(@"FMAVEffect FMAVEffectGLProgram compile fragment shader error: %s", log);
            }
            
            free(log);
        }
    }
    
    return status == GL_TRUE;
}

- (void)addAttribute:(NSString *)attributeName
{
    if (![self.attributes containsObject:attributeName])
    {
        [self.attributes addObject:attributeName];
        glBindAttribLocation(self.program,
                             (GLuint)[self.attributes indexOfObject:attributeName],
                             [attributeName UTF8String]);
    }
}

- (GLuint)attributeIndex:(NSString *)attributeName
{
    return (GLuint)[self.attributes indexOfObject:attributeName];
}

- (GLuint)uniformIndex:(NSString *)uniformName
{
    if ([self.uniforms.allKeys containsObject:uniformName]) {
        return (GLuint)[self.uniforms[uniformName] unsignedIntValue];
    }
    int loc = glGetUniformLocation(self.program, [uniformName UTF8String]);
    _uniforms[uniformName] = [NSNumber numberWithInt:loc];
    return loc;
}

- (BOOL)link
{
    GLint status;
    
    glLinkProgram(self.program);
    
    glGetProgramiv(self.program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE)
        return NO;
    
    if (self.vertShader)
    {
        glDeleteShader(self.vertShader);
        self.vertShader = 0;
    }
    if (self.fragShader)
    {
        glDeleteShader(self.fragShader);
        self.fragShader = 0;
    }
    return YES;
}

- (void)use
{
    glUseProgram(self.program);
}

- (void)dealloc
{
    if (_vertShader!=0)
        glDeleteShader(_vertShader);
    
    if (_fragShader!=0)
        glDeleteShader(_fragShader);
    
    if (_program!=0)
        glDeleteProgram(_program);
    
}

@end
