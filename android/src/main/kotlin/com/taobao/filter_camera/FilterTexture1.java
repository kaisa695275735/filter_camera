package com.taobao.filter_camera;

import android.graphics.SurfaceTexture;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.Looper;
import android.view.Surface;

import javax.microedition.khronos.egl.EGL;

import io.flutter.view.TextureRegistry;

public class FilterTexture1 implements  FilterCameraListener{
    protected SurfaceTexture externalTexture;
    protected TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;

    private  SurfaceTest surfaceTest;

    private FilterCamera filterCamera;
    private EGLDraw mDrawer;//OpenGL绘制

    private Surface mSurface;

    private Handler mGLHandler;

    final private EGLHelper  mEglHelper = new EGLHelper();

    FilterTexture1(){
        startThread();

        surfaceTest = new SurfaceTest();
    }

    @Override
    public void onFilterFrame(int frameTexture,int width,int height) {
        mEglHelper.makeCurrent();
        EGLHelper.checkEglError("aa");

        GLES20.glClearColor(1.0f, 1.0f, 0.0f, 1.0f);
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT);
        EGLHelper.checkEglError("aa");

        mDrawer.draw(frameTexture);
        EGLHelper.checkEglError("aa");

        mEglHelper.swapBuffers();
        EGLHelper.checkEglError("aa");
    }

    private void startThread(){
        Thread glThread = new Thread(new Runnable() {
            @Override
            public void run() {
                Looper.prepare();

                mGLHandler = new Handler();
                //init camera
                initCamera();
                //init camera opengl
                mEglHelper.initOpenGL();
                //update surface width and height
                updateTexture();
                //start camera with exist opengl environment
                startCamera();

                Looper.loop();
            }
        });
        glThread.setName("com.taobao.filter.camera");
        glThread.start();
    }

    private void updateTexture(){
        int width = filterCamera.getVideoWidth();
        int height = filterCamera.getVideoHeight();

//        externalTexture.setDefaultBufferSize(width,height);
//
//        mSurface = new Surface(externalTexture);

        surfaceTest.surfaceTexture.setDefaultBufferSize(width,height);

        mSurface = new Surface(surfaceTest.surfaceTexture);

        //5，创建EGLSurface实例
        mEglHelper.createWindowSurface(mSurface);

        //6, set context
        mEglHelper.makeCurrent();

        // 黄色清屏
        GLES20.glClearColor(1.0f, 1.0f, 0.0f, 1.0f);
        mDrawer = new EGLDraw();

        //更新摄像头的surfaceTexture
        filterCamera.updateSurfaceTexture();
    }

    private void initCamera(){
        filterCamera = new FilterCamera(this,1920,1080);
    }

    private void startCamera(){
        filterCamera.startPreview();
    }

    public void release() {
        mEglHelper.release();

        if(mDrawer != null){
            mDrawer.release();
        }
    }

}
