#import "FilterCameraPlugin.h"
#import <filter_camera/filter_camera-Swift.h>

@implementation FilterCameraPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFilterCameraPlugin registerWithRegistrar:registrar];
}
@end
