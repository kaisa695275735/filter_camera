#import "FilterCameraPlugin.h"
#import "FilterTexture1.h"
#import "FilterTexture2.h"

@interface FilterCameraPlugin()
@property(readonly, nonatomic) NSObject<FlutterTextureRegistry>     *registry;
@property(readonly, nonatomic) NSObject<FlutterBinaryMessenger>     *messenger;

@property(nonatomic, strong)   EAGLContext                          *playGLContext;
@property(strong, nonatomic)   FilterTexture2                       *shareTexture;
@property(strong, nonatomic)   FilterTexture1                       *pixelTexture;
@property(nonatomic,strong)    dispatch_queue_t                     playQueue;

@end

@implementation FilterCameraPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel =
    [FlutterMethodChannel methodChannelWithName:@"filter_camera"
                                binaryMessenger:[registrar messenger]];
    FilterCameraPlugin* instance =
    [[FilterCameraPlugin alloc] initWithRegistry:[registrar textures]
                                   messenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry>*)registry
                       messenger:(NSObject<FlutterBinaryMessenger>*)messenger {
    self = [super init];
    NSAssert(self, @"super init cannot be nil");
    _registry = registry;
    _messenger = messenger;
    _playQueue = dispatch_queue_create("com.taobao.FilterTextureQueue", nil);
    return self;
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"start_preview" isEqualToString:call.method]) {
        if(self.playGLContext == NULL){
            self.playGLContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3 sharegroup:[_registry getShareGroup]];
        }
        NSDictionary* argsMap = call.arguments;
        BOOL useShare = [argsMap[@"use_share_texture"] boolValue];
        if(useShare){
            self.shareTexture = [[FilterTexture2 alloc] initWithRegistry:_registry];
            int64_t textureID = [self.registry registerShareTexture:self.shareTexture];
            self.shareTexture.textureId = textureID;
            self.shareTexture.glContext = self.playGLContext;
            self.shareTexture.glQueue = self.playQueue;
            result(@(textureID));
        }
        else{
            self.pixelTexture = [[FilterTexture1 alloc] initWithRegistry:_registry];
            int64_t textureID = [self.registry registerTexture:self.pixelTexture];
            self.pixelTexture.textureId = textureID;
            self.pixelTexture.glContext = self.playGLContext;
            self.pixelTexture.glQueue = self.playQueue;
            result(@(textureID));
        }
    }
    else if ([@"stop_preview" isEqualToString:call.method]) {
        if(self.pixelTexture != NULL){
            [self.pixelTexture.filterCamera stopPreview];
            self.pixelTexture = NULL;
        }
        if(self.shareTexture != NULL){
            [self.shareTexture.filterCamera stopPreview];
            self.shareTexture = NULL;
        }
        result(@(YES));
    }
    
}

@end
