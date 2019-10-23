//
//  FilterCamera.h
//  filter_camera
//
//  Created by vigoss on 2019/9/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol FilterCameraDelegate <NSObject>
- (void)onBufferOutput:(CMSampleBufferRef)buffer;
@end

@interface FilterCamera : NSObject
@property(nonatomic,weak)       id<FilterCameraDelegate>            delegate;

- (void)startPreview;
- (void)stopPreview;
@end

NS_ASSUME_NONNULL_END
