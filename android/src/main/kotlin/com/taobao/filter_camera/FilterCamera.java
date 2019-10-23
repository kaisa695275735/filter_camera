package com.taobao.filter_camera;

import android.graphics.SurfaceTexture;
import android.hardware.Camera;
import android.util.Log;

import java.io.IOException;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;

public class FilterCamera implements SurfaceTexture.OnFrameAvailableListener{
    private static final int CAMERA_ID = 0;
    private static final String TAG = FilterCamera.class.getSimpleName();
    private Camera mCamera;
    private int mRotation;
    private boolean mIsFrontFace;
    private int mVideoWidth = 1920, mVideoHeight = 1080;
    private FilterCameraListener mListener;

    private SurfaceTexture mSurfaceTexture;//渲染纹理
    private int mTextureId;

    public FilterCamera(FilterCameraListener listener,int width,int height) {
        mListener = listener;

        if (mCamera == null) {
            try {
                mCamera = Camera.open(CAMERA_ID);
                final Camera.Parameters params = mCamera.getParameters();
                final List<String> focusModes = params.getSupportedFocusModes();
                if (focusModes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO)) {
                    params.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_VIDEO);
                } else if(focusModes
                        .contains(Camera.Parameters.FOCUS_MODE_AUTO)) {
                    params.setFocusMode(Camera.Parameters.FOCUS_MODE_AUTO);
                } else {
                    Log.i(TAG, "Camera does not support autofocus");
                }
                final List<int[]> supportedFpsRange = params.getSupportedPreviewFpsRange();
                final int[] max_fps = supportedFpsRange.get(supportedFpsRange.size() - 1);
                params.setPreviewFpsRange(max_fps[0], max_fps[1]);
                params.setRecordingHint(true);
                final Camera.Size closestSize = getClosestSupportedSize(params.getSupportedPreviewSizes(), width, height);
                params.setPreviewSize(closestSize.width, closestSize.height);
                final Camera.Size pictureSize = getClosestSupportedSize(params.getSupportedPictureSizes(), width, height);
                params.setPictureSize(pictureSize.width, pictureSize.height);
                //调整相机角度
                setRotation(params);
                mCamera.setParameters(params);
            } catch (Exception e) {
                Log.e(TAG, "initCamera:", e);
                if (mCamera != null) {
                    mCamera.release();
                    mCamera = null;
                }
            }
        }
    }

    public void updateSurfaceTexture(){
        final Camera.Size previewSize = mCamera.getParameters().getPreviewSize();

        // 创建纹理ID
        mTextureId = EGLHelper.initTextureId();
        // 创建渲染纹理
        mSurfaceTexture = new SurfaceTexture(mTextureId);
        mSurfaceTexture.setOnFrameAvailableListener(this);
        Log.i(TAG, String.format("previewSize(%d, %d)", previewSize.width, previewSize.height));
        mSurfaceTexture.setDefaultBufferSize(previewSize.width, previewSize.height);

        try {
            mCamera.setPreviewTexture(mSurfaceTexture);//相机和opengl纹理绑定
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    public void startPreview(){
        if(mCamera == null){
            return;
        }
        try {
            if (mCamera != null) {
                //开启摄像头预览
                mCamera.startPreview();
            }
        }catch (Exception e){
            Log.e(TAG, "startPreview:", e);
            if (mCamera != null) {
                mCamera.release();
                mCamera = null;
            }
        }
    }

    public void stopPreview(){
        Log.v(TAG, "stopPreview:");
        if (mCamera != null) {
            mCamera.stopPreview();
            mCamera.release();
            mCamera = null;
        }
    }

    private static Camera.Size getClosestSupportedSize(List<Camera.Size> supportedSizes, final int requestedWidth, final int requestedHeight) {
        return (Camera.Size) Collections.min(supportedSizes, new Comparator<Camera.Size>() {

            private int diff(final Camera.Size size) {
                return Math.abs(requestedWidth - size.width) + Math.abs(requestedHeight - size.height);
            }

            @Override
            public int compare(final Camera.Size lhs, final Camera.Size rhs) {
                return diff(lhs) - diff(rhs);
            }
        });
    }

    /**
     * 设置摄像头角度
     * @param params
     */
    private final void setRotation(final Camera.Parameters params) {
        int degrees = 0;
        final Camera.CameraInfo info = new android.hardware.Camera.CameraInfo();
        android.hardware.Camera.getCameraInfo(CAMERA_ID, info);
        mIsFrontFace = (info.facing == Camera.CameraInfo.CAMERA_FACING_FRONT);
        if (mIsFrontFace) { // 前置摄像头
            degrees = (info.orientation + degrees) % 360;
            degrees = (360 - degrees) % 360;  // reverse
        } else {  // 后置摄像头
            degrees = (info.orientation - degrees + 360) % 360;
        }
        mCamera.setDisplayOrientation(degrees);
        mRotation = degrees;
        Log.d(TAG, "setRotation:" + degrees);
    }

    public int getVideoHeight() {
        return mCamera.getParameters().getPreviewSize().height;
    }

    public int getVideoWidth() {
        return mCamera.getParameters().getPreviewSize().width;
    }

    @Override
    public void onFrameAvailable(SurfaceTexture surfaceTexture) {
        //更新纹理（摄像头已经绑定该SurfaceTexture）
        mSurfaceTexture.updateTexImage();
        if(mListener != null){
            mListener.onFilterFrame(mTextureId,mVideoWidth,mVideoHeight);
        }
    }
}
