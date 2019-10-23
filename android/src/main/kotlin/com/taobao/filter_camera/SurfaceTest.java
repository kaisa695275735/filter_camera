package com.taobao.filter_camera;

import android.annotation.SuppressLint;
import android.graphics.SurfaceTexture;
import android.opengl.GLES11Ext;
import android.opengl.GLES20;
import android.os.Handler;
import android.os.Looper;
import android.os.Message;
import android.util.Log;

public class SurfaceTest implements SurfaceTexture.OnFrameAvailableListener{
    final SurfaceTexture surfaceTexture;

    private boolean mFrameAvailable = false;
    private boolean mIsAttached = false;
    private int     mTextureId;

    final private EGLHelper  mEglHelper = new EGLHelper();

    Handler mTestHandler;


    SurfaceTest(){
        surfaceTexture = new SurfaceTexture(0);
        surfaceTexture.detachFromGLContext();
        surfaceTexture.setOnFrameAvailableListener(this);

        startTestThread();
    }

    private void startTestThread(){
        @SuppressLint("HandlerLeak") final Handler handler = new Handler() {
            public void handleMessage(Message msg) {
                Log.d("handleMessage","null");
                super.handleMessage(msg);
                mEglHelper.makeCurrent();
                if(mFrameAvailable){
                    mFrameAvailable = false;
                    if(!mIsAttached){
                        mIsAttached = true;
                        mTextureId = EGLHelper.initTextureId();
                        surfaceTexture.attachToGLContext(mTextureId);
                    }
                    surfaceTexture.updateTexImage();
                }
            }
        };

        Thread glThread = new Thread(new Runnable() {
            @Override
            public void run() {
                Looper.prepare();
                mEglHelper.initOpenGL();

                //5，创建EGLSurface实例
                mEglHelper.createBufferSurface();

                //6, set context
                mEglHelper.makeCurrent();

//                while (true) {
//                    try {
//                        Thread.sleep(100);//线程暂停10秒，单位毫秒
//                        Message message=new Message();
//                        message.what=1;
//                        handler.sendMessage(message);//发送消息
//                    } catch (InterruptedException e) {
//                        e.printStackTrace();
//                    }
//                }
                Looper.loop();
            }
        });
        glThread.setName("com.taobao.filter.test");
        glThread.start();
    }

    @Override
    public void onFrameAvailable(SurfaceTexture surfaceTexture) {
        mFrameAvailable = true;
    }
}
