package com.taobao.filter_camera;

import android.opengl.EGL14;
import android.opengl.EGLConfig;
import android.opengl.EGLContext;
import android.opengl.EGLDisplay;
import android.opengl.EGLSurface;
import android.opengl.GLES11Ext;
import android.opengl.GLES20;
import android.util.Log;

public class EGLHelper {
    private static final String TAG = "MEgl";
    private EGLDisplay mEglDisplay = EGL14.EGL_NO_DISPLAY;
    private EGLContext mEglContext = EGL14.EGL_NO_CONTEXT;
    private EGLConfig mEglConfig;
    private EGLSurface mEGLSurface;
    private EGLContext mDefaultContext = EGL14.EGL_NO_CONTEXT;
    /**
     * create external texture
     * @return texture ID
     */
    public static int initTextureId() {
        final int[] tex = new int[1];
        //创建纹理
        GLES20.glGenTextures(1, tex, 0);
        //纹理帮定的目标(target)并不是通常的GL_TEXTURE_2D，而是GL_TEXTURE_EXTERNAL_OES,这是因为Camera使用的输出texture是一种特殊的格式
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, tex[0]);
        //纹理坐标系用S-T来表示，S为横轴，T为纵轴。
        // 参数1：纹理类型，参数2：纹理环绕方向， 参数3：纹理坐标范围（GL_CLAMP_TO_EDGE：纹理坐标到[1/2n,1-1/2n]，GL_CLAMP：截取纹理坐标到 [0,1]）
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE);
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE);
        //第二个参数指定滤波方法，其中参数值GL_TEXTURE_MAG_FILTER指定为放大滤波方法，
        // GL_TEXTURE_MIN_FILTER指定为缩小滤波方法；第三个参数说明滤波方式
        //GL_NEAREST则采用坐标最靠近象素中心的纹素，这有可能使图像走样；
        // 若选择GL_LINEAR则采用最靠近象素中心的四个象素的加权平均值。
        // GL_NEAREST所需计算比GL_LINEAR要少，因而执行得更快，但GL_LINEAR提供了比较光滑的效果。
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_NEAREST);
        GLES20.glTexParameteri(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_NEAREST);
        Log.v(TAG, "initTextureId:" + tex[0]);
        return tex[0];
    }

    public void initOpenGL(){

        Log.v(TAG, "init:");
        if (mEglDisplay != EGL14.EGL_NO_DISPLAY) {
            throw new RuntimeException("EGL already set up");
        }
        //1，获取EGLDisplay对象
        mEglDisplay = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY);
        if (mEglDisplay == EGL14.EGL_NO_DISPLAY) {
            Log.e(TAG, "eglGetDisplay failed");
        }

        final int[] version = new int[2];
        // 2，初始化与EGLDisplay 之间的连接。
        if (!EGL14.eglInitialize(mEglDisplay, version, 0, version, 1)) {
            mEglDisplay = null;
            Log.e(TAG, "eglInitialize failed");
        }

        if (mEglContext == EGL14.EGL_NO_CONTEXT) {
            //3，获取EGLConfig对象
            mEglConfig = getConfig();
            if (mEglConfig == null) {
                Log.e(TAG, "chooseConfig failed");
            }
            //  4，创建EGLContext 实例
            mEglContext = createContext(EGL14.EGL_NO_CONTEXT);
        }
        // confirm whether the EGL rendering context is successfully created
        final int[] values = new int[1];
        EGL14.eglQueryContext(mEglDisplay, mEglContext, EGL14.EGL_CONTEXT_CLIENT_VERSION, values, 0);
        Log.d(TAG, "EGLContext created, client version " + values[0]);
        checkEglError("aa");

        makeDefault();  // makeCurrent(EGL14.EGL_NO_SURFACE);

        checkEglError("aa");
    }

    public void release() {
        Log.v(TAG, "release:");
        if (mEglDisplay != EGL14.EGL_NO_DISPLAY) {
            destroyContext();
            EGL14.eglTerminate(mEglDisplay);
            EGL14.eglReleaseThread();
        }
        mEglDisplay = EGL14.EGL_NO_DISPLAY;
        mEglContext = EGL14.EGL_NO_CONTEXT;
    }

    /**
     * 6，连接EGLContext和EGLSurface.
     * @return
     */
    public boolean makeCurrent() {
//      if (DEBUG) Log.v(TAG, "makeCurrent:");
        if (mEglDisplay == null) {
            Log.d(TAG, "makeCurrent:eglDisplay not initialized");
        }
        if (mEGLSurface == null || mEGLSurface == EGL14.EGL_NO_SURFACE) {
            final int error = EGL14.eglGetError();
            if (error == EGL14.EGL_BAD_NATIVE_WINDOW) {
                Log.e(TAG, "makeCurrent:returned EGL_BAD_NATIVE_WINDOW.");
            }
            return false;
        }
        // attach EGL renderring context to specific EGL window surface
        if (!EGL14.eglMakeCurrent(mEglDisplay, mEGLSurface, mEGLSurface, mEglContext)) {
            Log.w(TAG, "eglMakeCurrent:" + EGL14.eglGetError());
            return false;
        }
        return true;
    }

    public void swapBuffers(){
        if (!EGL14.eglSwapBuffers(mEglDisplay, mEGLSurface)) {
            final int err = EGL14.eglGetError();
            Log.w(TAG, "swap:err=" + err);
        }
    }

    private EGLConfig getConfig() {
        final int[] attribList = {
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_RED_SIZE, 8,//指定RGB中R的大小
                EGL14.EGL_GREEN_SIZE, 8,//指定G大小
                EGL14.EGL_BLUE_SIZE, 8,//指定B大小
                EGL14.EGL_ALPHA_SIZE, 8,//指定Alpha大小
                EGL14.EGL_NONE, EGL14.EGL_NONE, //EGL14.EGL_STENCIL_SIZE, 8,
                EGL14.EGL_NONE, EGL14.EGL_NONE, //EGL_RECORDABLE_ANDROID, 1,    // this flag need to recording of MediaCodec
                EGL14.EGL_NONE, EGL14.EGL_NONE, //  with_depth_buffer ? EGL14.EGL_DEPTH_SIZE : EGL14.EGL_NONE,
                // with_depth_buffer ? 16 : 0,
                EGL14.EGL_NONE
        };
        int offset = 10;
        for (int i = attribList.length - 1; i >= offset; i--) {
            attribList[i] = EGL14.EGL_NONE;
        }
        final EGLConfig[] configs = new EGLConfig[1];
        final int[] numConfigs = new int[1];
        if (!EGL14.eglChooseConfig(mEglDisplay, attribList, 0, configs, 0, configs.length, numConfigs, 0)) {
            // XXX it will be better to fallback to RGB565
            Log.w(TAG, "unable to find RGBA8888 / " + " EGLConfig");
            return null;
        }
        return configs[0];
    }

    public static void checkEglError(final String msg) {
        int error;
        if ((error = EGL14.eglGetError()) != EGL14.EGL_SUCCESS) {
            throw new RuntimeException(msg + ": EGL error: 0x" + Integer.toHexString(error));
        }
    }

    private void destroyContext() {
        Log.v(TAG, "destroyContext:");

        if (!EGL14.eglDestroyContext(mEglDisplay, mEglContext)) {
            Log.e("destroyContext", "display:" + mEglDisplay + " context: " + mEglContext);
            Log.e(TAG, "eglDestroyContex:" + EGL14.eglGetError());
        }
        mEglContext = EGL14.EGL_NO_CONTEXT;
        if (mDefaultContext != EGL14.EGL_NO_CONTEXT) {
            if (!EGL14.eglDestroyContext(mEglDisplay, mDefaultContext)) {
                Log.e("destroyContext", "display:" + mEglDisplay + " context: " + mDefaultContext);
                Log.e(TAG, "eglDestroyContex:" + EGL14.eglGetError());
            }
            mDefaultContext = EGL14.EGL_NO_CONTEXT;
        }
    }

    public void createBufferSurface(){
        Log.v(TAG, "createBufferSurface:");
        final int[] surfaceAttribs = {
                EGL14.EGL_WIDTH, 16,
                EGL14.EGL_HEIGHT, 16,
                EGL14.EGL_NONE
        };
        try {
            mEGLSurface = EGL14.eglCreatePbufferSurface(mEglDisplay, mEglConfig, surfaceAttribs, 0);
        } catch (final IllegalArgumentException e) {
            Log.e(TAG, "eglCreateWindowSurface", e);
        }
    }

    public void createWindowSurface(final Object nativeWindow) {
        Log.v(TAG, "createWindowSurface:nativeWindow=" + nativeWindow);
        final int[] surfaceAttribs = {
                EGL14.EGL_NONE
        };
        try {
            mEGLSurface = EGL14.eglCreateWindowSurface(mEglDisplay, mEglConfig, nativeWindow, surfaceAttribs, 0);
        } catch (final IllegalArgumentException e) {
            Log.e(TAG, "eglCreateWindowSurface", e);
        }
    }

    private void makeDefault() {
        Log.v(TAG, "makeDefault:");
        if (!EGL14.eglMakeCurrent(mEglDisplay, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)) {
            Log.w("TAG", "makeDefault" + EGL14.eglGetError());
        }
    }

    private EGLContext createContext(final EGLContext shared_context) {
//      if (DEBUG) Log.v(TAG, "createContext:");

        final int[] attrib_list = {
                EGL14.EGL_CONTEXT_CLIENT_VERSION, 2,
                EGL14.EGL_NONE
        };
        final EGLContext context = EGL14.eglCreateContext(mEglDisplay, mEglConfig, shared_context, attrib_list, 0);
        checkEglError("eglCreateContext");
        return context;
    }
}
