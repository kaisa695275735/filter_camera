package com.taobao.filter_camera;

import android.graphics.SurfaceTexture;
import android.util.LongSparseArray;

import java.util.logging.Filter;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.view.TextureRegistry;

public class FilterCameraPlugin implements MethodChannel.MethodCallHandler {
    private final PluginRegistry.Registrar registrar;
    private final CameraPermissions cameraPermissions = new CameraPermissions();
    private FilterTexture1 filterTexture1;
    private FilterTexture2 filterTexture2;
    public static void registerWith(PluginRegistry.Registrar registrar) {
        final MethodChannel channel =
                new MethodChannel(registrar.messenger(), "filter_camera");
        channel.setMethodCallHandler(new FilterCameraPlugin(registrar));
    }

    private FilterCameraPlugin(PluginRegistry.Registrar registrar) {
        this.registrar = registrar;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (call.method.equals("start_preview")) {
            final MethodChannel.Result finalResult = result;
            cameraPermissions.requestPermissions(
                    registrar,
                    new CameraPermissions.ResultCallback() {
                        @Override
                        public void onResult(String errCode, String errDesc) {
                            if (errCode == null) {
                                try {
                                    TextureRegistry.SurfaceTextureEntry textureEntry = registrar.textures().createSurfaceTexture();
                                    filterTexture1 = new FilterTexture1();
                                    filterTexture1.externalTexture = textureEntry.surfaceTexture();
                                    filterTexture1.surfaceTextureEntry = textureEntry;
                                    finalResult.success(textureEntry.id());
                                } catch (Exception e) {
                                }
                            } else {
                            }
                        }
                    });


        }
        else if(call.method.equals("stop_preview")){
            if(filterTexture1 != null){
                filterTexture1.release();
                filterTexture1 = null;
            }
            else if(filterTexture2 != null){
            }
        }
        else{
            result.notImplemented();
        }
    }
}
