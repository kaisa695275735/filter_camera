package com.taobao.filter_camera;

import android.opengl.GLES11Ext;
import android.opengl.GLES20;
import android.opengl.Matrix;
import android.util.Log;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;

public class EGLDraw {
    private static final String TAG = "GLDrawer2D";

    //顶点shader,画点
    private static final String vss
            = "attribute highp vec4 aPosition;\n"
            + "attribute highp vec4 aTextureCoord;\n"
            + "varying highp vec2 vTextureCoord;\n"
            + "\n"
            + "void main() {\n"
            + " gl_Position = aPosition;\n"
            + " vTextureCoord = aTextureCoord.xy;\n"
            + "}\n";
    //片元shader，画面
    private static final String fss
            = "#extension GL_OES_EGL_image_external : require\n"
            + "precision mediump float;\n"
            + "uniform samplerExternalOES sTexture;\n"
            + "varying highp vec2 vTextureCoord;\n"
            + "void main() {\n"
            + "  gl_FragColor = texture2D(sTexture, vTextureCoord);\n"
            + "}";
    private static final float[] VERTICES = {
            -1.0f, -1.0f,
            -1.0f, 1.0f,
            1.0f, -1.0f,
            1.0f, 1.0f };
    private static final float[] TEXCOORD = {
            0.0f, 0.0f,
            0.0f, 1.0f,
            1.0f, 0.0f,
            1.0f, 1.0f };

    private final FloatBuffer pVertex;
    private final FloatBuffer pTexCoord;
    private int hProgram;
    int maPositionLoc;
    int maTextureCoordLoc;//纹理坐标引用

    private static final int FLOAT_SZ = Float.SIZE / 8;
    private static final int VERTEX_NUM = 4;
    private static final int VERTEX_SZ = VERTEX_NUM * 2;
    /**
     * Constructor
     * this should be called in GL context
     */
    public EGLDraw() {
        /**
         * 获取图形的顶点
         * 特别提示：由于不同平台字节顺序不同数据单元不是字节的一定要经过ByteBuffer
         * 转换，关键是要通过ByteOrder设置nativeOrder()，否则有可能会出问题
         *
         */
        pVertex = ByteBuffer.allocateDirect(VERTEX_SZ * FLOAT_SZ).order(ByteOrder.nativeOrder()).asFloatBuffer();
        pVertex.put(VERTICES);
        pVertex.flip();
        /**
         * 同上
         */
        pTexCoord = ByteBuffer.allocateDirect(VERTEX_SZ * FLOAT_SZ).order(ByteOrder.nativeOrder()).asFloatBuffer();
        pTexCoord.put(TEXCOORD);
        pTexCoord.flip();

        hProgram = loadShader(vss, fss);
        //使用shader程序
        GLES20.glUseProgram(hProgram);
        /**
         * attribute变量是只能在vertex shader中使用的变量。（它不能在fragment shader中声明attribute变量，也不能被fragment shader中使用）
         一般用attribute变量来表示一些顶点的数据，如：顶点坐标，法线，纹理坐标，顶点颜色等。
         在application中，一般用函数glBindAttribLocation（）来绑定每个attribute变量的位置，然后用函数glVertexAttribPointer（）为每个attribute变量赋值。
         */
        maPositionLoc = GLES20.glGetAttribLocation(hProgram, "aPosition");
        maTextureCoordLoc = GLES20.glGetAttribLocation(hProgram, "aTextureCoord");

    }

    /**
     * terminatinng, this should be called in GL context
     */
    public void release() {
        if (hProgram >= 0)
            GLES20.glDeleteProgram(hProgram);
        hProgram = -1;
    }

    /**
     * draw specific texture with specific texture matrix
     * @param tex_id texture ID
     */
    public void draw(final int tex_id) {
        GLES20.glUseProgram(hProgram);

        //将顶点位置数据传送进渲染管线, 为画笔指定顶点的位置坐标数据
        GLES20.glVertexAttribPointer(maPositionLoc, 2, GLES20.GL_FLOAT, false, VERTEX_SZ, pVertex);
        GLES20.glVertexAttribPointer(maTextureCoordLoc, 2, GLES20.GL_FLOAT, false, VERTEX_SZ, pTexCoord);

        //将纹理数据传进渲染管线，为画笔指定纹理坐标数据
        GLES20.glEnableVertexAttribArray(maPositionLoc);
        GLES20.glEnableVertexAttribArray(maTextureCoordLoc);

        //激活纹理
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0);
        //绑定纹理
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, tex_id);
        //第一个参数表示绘制方式（三角形），第二个参数表示偏移量，第三个参数表示顶点个数。
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, VERTEX_NUM);


        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, 0);
        GLES20.glUseProgram(0);
    }

    /**
     * delete specific texture
     */
    public static void deleteTex(final int hTex) {
        Log.v(TAG, "deleteTex:");
        final int[] tex = new int[] {hTex};
        GLES20.glDeleteTextures(1, tex, 0);
    }

    /**
     * load, compile and link shader
     * @param vss source of vertex shader
     * @param fss source of fragment shader
     * @return
     */
    public static int loadShader(final String vss, final String fss) {
        Log.v(TAG, "loadShader:");
        int vs = GLES20.glCreateShader(GLES20.GL_VERTEX_SHADER);
        GLES20.glShaderSource(vs, vss);//加载顶点 shader
        GLES20.glCompileShader(vs);//编译shader
        final int[] compiled = new int[1];
        //获取shader的编译结果
        GLES20.glGetShaderiv(vs, GLES20.GL_COMPILE_STATUS, compiled, 0);
        if (compiled[0] == 0) {//获取失败，删除shader并log
            Log.e(TAG, "Failed to compile vertex shader:" + GLES20.glGetShaderInfoLog(vs));
            GLES20.glDeleteShader(vs);
            vs = 0;
        }
        //创建片元着色器
        int fs = GLES20.glCreateShader(GLES20.GL_FRAGMENT_SHADER);
        GLES20.glShaderSource(fs, fss);
        GLES20.glCompileShader(fs);
        GLES20.glGetShaderiv(fs, GLES20.GL_COMPILE_STATUS, compiled, 0);
        if (compiled[0] == 0) {
            Log.w(TAG, "Failed to compile fragment shader:" + GLES20.glGetShaderInfoLog(fs));
            GLES20.glDeleteShader(fs);
            fs = 0;
        }

        //创建shader程序
        int program = GLES20.glCreateProgram();
        if(program != 0) {//创建成功
            //加入顶点着色器
            GLES20.glAttachShader(program, vs);
            //加入片元着色器
            GLES20.glAttachShader(program, fs);
            //链接程序
            GLES20.glLinkProgram(program);
            int[] linkStatus = new int[1];
            //获取链接程序结果
            GLES20.glGetProgramiv(program, GLES20.GL_LINK_STATUS, linkStatus, 0);
            // 若链接失败则报错并删除程序
            if (linkStatus[0] != GLES20.GL_TRUE) {
                Log.e(TAG, "Could not link program: ");
                Log.e(TAG, GLES20.glGetProgramInfoLog(program));
                GLES20.glDeleteProgram(program);
                program = 0;
            }
        }
        return program;
    }

}
