//
//  FilterTexture2.h
//  filter_camera
//
//  Created by vigoss on 2019/9/26.
//

#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>
#import "FilterCamera.h"

NS_ASSUME_NONNULL_BEGIN

@interface FilterTexture2 : NSObject <FlutterShareTexture>
- (instancetype)initWithRegistry:(NSObject<FlutterTextureRegistry> *)registry;
@property(strong,nonatomic) FilterCamera            *filterCamera;
@property(assign,nonatomic) int64_t                 textureId;
@property(nonatomic,strong) EAGLContext             *glContext;
@property(nonatomic,strong) dispatch_queue_t        glQueue;
@end

NS_ASSUME_NONNULL_END
