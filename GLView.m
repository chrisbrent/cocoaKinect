//  Created by fernlightning on 18/11/2010.

#import "GLView.h"

#import "AppDelegate.h"
#import "GLProgram.h"

static void gluPerspectivef(GLfloat fovy, GLfloat aspect, GLfloat zNear, GLfloat zFar) {
    GLfloat f = 1.0f / tanf(fovy * (M_PI/360.0));
	GLfloat m[16];
    
	m[0] = f / aspect;
	m[1] = 0.0;
	m[2] = 0.0;
	m[3] = 0.0;
    
	m[4] = 0.0;
	m[5] = f;
	m[6] = 0.0;
	m[7] = 0.0;
    
	m[8] = 0.0;
	m[9] = 0.0;
	m[10] = (zFar + zNear) / (zNear - zFar);
	m[11] = -1.0;
    
	m[12] = 0.0;
	m[13] = 0.0;
	m[14] = 2.0 * zFar * zNear / (zNear - zFar);
	m[15] = 0.0;
    
	glMultMatrixf(m);
}

@interface GLView()
- (void)initScene;
- (void)closeScene;
- (void)drawScene;
- (void)frameForTime:(const CVTimeStamp*)outputTime;
@end


@implementation GLView

// This is the renderer output callback function
static CVReturn displayLinkCallback(CVDisplayLinkRef displayLink, const CVTimeStamp* now, const CVTimeStamp* outputTime, CVOptionFlags flagsIn, CVOptionFlags* flagsOut, void* displayLinkContext) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    [(GLView*)displayLinkContext frameForTime:outputTime];
    [pool release];
    return kCVReturnSuccess;
}

- (id) initWithFrame: (NSRect) frame
{
	GLuint attribs[] = 
    {
        NSOpenGLPFAAccelerated,
        NSOpenGLPFADoubleBuffer,
        NSOpenGLPFANoRecovery,
        NSOpenGLPFAColorSize, 32,
        NSOpenGLPFADepthSize, 24,
        0
    };	
	NSOpenGLPixelFormat* fmt = [[NSOpenGLPixelFormat alloc] initWithAttributes: (NSOpenGLPixelFormatAttribute*) attribs]; 
	if((self = [super initWithFrame:frame pixelFormat: [fmt autorelease]])) {
    }
    return self;
}

- (void)dealloc {
    CVDisplayLinkRelease(_displayLink);
    [self closeScene];
    [super dealloc];
}


- (void)prepareOpenGL { 
    // Synchronize buffer swaps with vertical refresh rate
    GLint swapInt = 1;
    [[self openGLContext] setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; 
    
    [self initScene];
    
    CVDisplayLinkCreateWithActiveCGDisplays(&_displayLink);
    CVDisplayLinkSetOutputCallback(_displayLink, &displayLinkCallback, self);
    
    // Set the display link for the current renderer
    CGLContextObj cglContext = [[self openGLContext] CGLContextObj];
    CGLPixelFormatObj cglPixelFormat = [[self pixelFormat] CGLPixelFormatObj];
    CVDisplayLinkSetCurrentCGDisplayFromOpenGLContext(_displayLink, cglContext, cglPixelFormat);
    
    CVDisplayLinkStart(_displayLink);
}

- (void)update {
    NSOpenGLContext *context = [self openGLContext];
    CGLLockContext([context CGLContextObj]);
    [super update];
    CGLUnlockContext([context CGLContextObj]);
}

- (void)reshape {
    NSOpenGLContext *context = [self openGLContext];
    CGLLockContext([context CGLContextObj]);
    NSView *view = [context view];
    if(view) {
        NSSize size = [self bounds].size;
        [context makeCurrentContext];
        glViewport(0, 0, size.width, size.height);
    }    
    CGLUnlockContext([context CGLContextObj]);
}


- (void)frameForTime:(const CVTimeStamp*)outputTime {
    [self drawRect:NSZeroRect];
}

- (void)drawRect:(NSRect)dirtyRect {
    NSOpenGLContext *context = [self openGLContext];
    CGLLockContext([context CGLContextObj]);
    NSView *view = [context view];
    if(view) {
        [context makeCurrentContext];
        
        [self drawScene];
        
        GLenum err = glGetError();
        if(err != GL_NO_ERROR) NSLog(@"GLError %4x", err);
        
        [context flushBuffer];
    }
    CGLUnlockContext([context CGLContextObj]);
}


#pragma mark custom drawing


- (void)initScene {
    
    uint8_t *empty = (uint8_t*)malloc(FREENECT_FRAME_W * FREENECT_FRAME_H * 3);
    bzero(empty, FREENECT_FRAME_W * FREENECT_FRAME_H * 3);
    
	glGenTextures(1, &_depthTex);
	glBindTexture(GL_TEXTURE_2D, _depthTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE16, FREENECT_FRAME_W, FREENECT_FRAME_H, 0, GL_LUMINANCE, GL_UNSIGNED_SHORT, empty);
    
	glGenTextures(1, &_videoTex);
	glBindTexture(GL_TEXTURE_2D, _videoTex);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, FREENECT_FRAME_W, FREENECT_FRAME_H, 0, GL_RGB, GL_UNSIGNED_BYTE, empty);
    
    free(empty);
    
    uint8_t map[2048*3];
    for(int i = 0; i < 2048; i++) {
        float v = i/2048.0;
		v = powf(v, 3)* 6;
        uint16_t gamma = v*6*256;
        
        int lb = gamma & 0xff;
		switch (gamma>>8) {
			case 0: // white -> red
                map[i*3+0] = 255;
				map[i*3+1] = 255-lb;
				map[i*3+2] = 255-lb;
				break;
			case 1: // red -> orange
				map[i*3+0] = 255;
				map[i*3+1] = lb;
				map[i*3+2] = 0;
				break;
			case 2: // orange -> green 
				map[i*3+0] = 255-lb;
				map[i*3+1] = 255;
				map[i*3+2] = 0;
				break;
			case 3: // green -> cyan
				map[i*3+0] = 0;
				map[i*3+1] = 255;
				map[i*3+2] = lb;
				break;
			case 4: // cyan -> blue
				map[i*3+0] = 0;
				map[i*3+1] = 255-lb;
				map[i*3+2] = 255;
				break;
			case 5: // blue -> black
				map[i*3+0] = 0;
				map[i*3+1] = 0;
				map[i*3+2] = 255-lb;
				break;
			default: // black
				map[i*3+0] = 0;
				map[i*3+1] = 0;
				map[i*3+2] = 0;
				break;
		}
	}
    glGenTextures(1, &_colormapTex);
    glBindTexture(GL_TEXTURE_1D, _colormapTex);
    glTexImage1D(GL_TEXTURE_1D, 0, GL_RGB8, 2048, 0, GL_RGB, GL_UNSIGNED_BYTE, map);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_1D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    
    _depthProgram = [[GLProgram alloc] initWithName:
                     @"depth"
                                                 VS:
                     "void main() {\n"
                     "	gl_TexCoord[0] = gl_MultiTexCoord0;\n"
                     "	gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;\n"
                     "}\n"
                                                 FS:
                     "uniform sampler1D colormap;\n"
                     "uniform sampler2D depth;\n"
                     "uniform sampler2D video;\n"
                     "uniform int normals;\n"
                     "uniform int natural;\n"
                     ""
                     "const float kMinDistance = -10.0;\n"
                     "const float kDepthScale  = 0.0021;\n"
                     "uniform float kColorScale;\n"
                     "uniform float kColorX;\n"
                     "uniform float kColorY;\n"
                     ""
                     "void main() {\n"
                     "	float z  = texture2D(depth, gl_TexCoord[0].st).r*32.0;\n" 
                     "   vec4 rgba;\n"
                     "   if(natural > 0) {\n"
                     ""
                     "      vec2 pos = gl_TexCoord[0].st*2.0-vec2(1.0);\n" // -1..+1
                     "      float d = z*2048.0;\n" // 0..2048
                     ""
                     "      float zd = (d > 1.0 && d < 1800.0) ? (100.0/(-0.00307 * d + 3.33)) : 100000.0;\n"
                     ""
                     "      float zs = (zd+kMinDistance)*kDepthScale;\n"
                     "      vec4 world = vec4(pos.x*320.0*zs, pos.y*240.0* zs, 200.0-zd, 1.0);\n"
                     ""
                     "      float cs = 1.0/((zd+kMinDistance)*kColorScale);\n"
                     "	   vec2 st = vec2( ((world.x+kColorX)*cs)/640.0 + 0.5,   ((world.y+kColorY)*cs)/480.0 + 0.5);\n"
                     ""
                     "      rgba = texture2D(video, st);\n"
                     "   } else {\n"
                     "      rgba = texture1D(colormap, z);\n" // scale to 0..1 range
                     "   }\n"
                     ""
                     "   if(normals > 0) {\n"
                     "      float zx =  texture2D(depth, gl_TexCoord[0].st+vec2(2.0/640.0, 0.0)).r*32.0;\n"
                     "      float zy =  texture2D(depth, gl_TexCoord[0].st+vec2(0.0, 2.0/480.0)).r*32.0;\n"
                     "      vec3 n = vec3(zx-z, zy-z, -0.0005);\n"
                     "      n = normalize(n);\n"
                     "      rgba *= max(0.1, dot(vec3(0.0, -0.3, -0.95), n));\n"
                     "   }\n"
                     ""
                     "   gl_FragColor = rgba;\n"
                     "}\n"];
    [_depthProgram bind];
    [_depthProgram setUniformInt:0 forName:@"video"];
    [_depthProgram setUniformInt:1 forName:@"depth"];
    [_depthProgram setUniformInt:2 forName:@"colormap"];
    [_depthProgram unbind];                     
    
    // create grid of points
    struct glf2 {
        GLfloat x,y;
    } *verts = (struct glf2*)malloc(FREENECT_FRAME_W*FREENECT_FRAME_H*sizeof(struct glf2));
    for(int x = 0; x < FREENECT_FRAME_W; x++) {
        for(int y = 0; y < FREENECT_FRAME_H; y++) {
            struct glf2 *v = verts+x+y*FREENECT_FRAME_W;
            v->x = (x+0.5)/(FREENECT_FRAME_W*0.5) - 1.0;
            v->y = (y+0.5)/(FREENECT_FRAME_H*0.5) - 1.0;
        }
    }
    glGenBuffers(1, &_pointBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _pointBuffer);
    glBufferData(GL_ARRAY_BUFFER, FREENECT_FRAME_W*FREENECT_FRAME_H*sizeof(struct glf2), verts, GL_STATIC_DRAW);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    free(verts);
    
    _pointProgram = [[GLProgram alloc] initWithName:
                     @"point"
                                                 VS:
                     "uniform sampler2D depth;\n"
                     ""
                     "const float kMinDistance = -10.0;\n"
                     "const float kDepthScale  = 0.0021;\n"
                     "uniform float kColorScale;\n"
                     "uniform float kColorX;\n"
                     "uniform float kColorY;\n"
                     ""
                     "void main() {\n"
                     "   vec3 pos = gl_Vertex.xyz;\n"
                     "   vec2 xy = (vec2(1.0)+pos.xy)*0.5;\n" // 0..1
                     "   float d = texture2D(depth, xy).r*32.0*2048.0;\n" // 0..2048
                     ""
                     "   float z = (d > 1.0 && d < 1800.0) ? (100.0/(-0.00307 * d + 3.33)) : 100000.0;\n"
                     ""
                     "   float zs = (z+kMinDistance)*kDepthScale;\n"
                     "   vec4 world = vec4(pos.x*320.0*zs, pos.y*240.0* zs, 200.0-z, 1.0);\n"
                     ""
                     "   float cs = 1.0/((z+kMinDistance)*kColorScale);\n"
                     "	gl_TexCoord[1].st = vec2( ((world.x+kColorX)*cs)/640.0 + 0.5,   ((world.y+kColorY)*cs)/480.0 + 0.5);\n"
                     "	gl_TexCoord[0].st = xy;\n"
                     ""
                     "	gl_Position = gl_ModelViewProjectionMatrix * world;\n"
                     "}\n"
                                                 FS:
                     "uniform sampler1D colormap;\n"
                     "uniform sampler2D depth;\n"
                     "uniform sampler2D video;\n"
                     "uniform int normals;\n"
                     "uniform int natural;\n"
                     ""
                     "void main() {\n"
                     "	float z  = texture2D(depth, gl_TexCoord[0].st).r*32.0;\n" // 0..1
                     "   vec4 rgba = (natural > 0) ? texture2D(video, gl_TexCoord[1].st) : texture1D(colormap, z);\n" 
                     ""
                     "   if(normals > 0) {\n"
                     "      float zx =  texture2D(depth, gl_TexCoord[0].st+vec2(2.0/640.0, 0.0)).r*32.0;\n"
                     "      float zy =  texture2D(depth, gl_TexCoord[0].st+vec2(0.0, 2.0/480.0)).r*32.0;\n"
                     "      vec3 n = vec3(zx-z, zy-z, -0.0005);\n"
                     "      n = normalize(n);\n"
                     "      rgba *= max(0.1, dot(vec3(0.0, -0.3, -0.95), n));\n"
                     "   }\n"
                     ""
                     "   gl_FragColor = rgba;\n"
                     "}\n"
                     ];
    [_pointProgram bind];
    [_pointProgram setUniformInt:0 forName:@"video"];
    [_pointProgram setUniformInt:1 forName:@"depth"];
    [_pointProgram setUniformInt:2 forName:@"colormap"];
    [_pointProgram unbind];
    
    // create indicies for mesh
    _indicies = (GLuint*)malloc(FREENECT_FRAME_W*FREENECT_FRAME_H*6*sizeof(GLuint));
    _nTriIndicies = 0;

    _offset[0] = 0;
    _offset[1] = 0;
    _offset[2] = 5;
    _angle = 0;
    _tilt = 0;
    
    // set up texture units 0,1,2 permantely and only bind the textures once
    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_1D, _colormapTex);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _depthTex);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _videoTex);
}

- (void)closeScene {
    glDeleteTextures(1, &_depthTex);
    glDeleteTextures(1, &_videoTex);
    glDeleteTextures(1, &_colormapTex);
    glDeleteBuffers(1, &_pointBuffer);
    
    free(_indicies);
    
    [_depthProgram release];
    [_pointProgram release];
}

- (void)drawFrustrum {
    struct glf3 {
        GLfloat x,y,z;
    } verts[] = {
        {0,    0,  30},
        {640,  0,  30},
        {640,480,  30},
        {0,  480,  30},
        {0,    0,2048},
        {640,  0,2048},
        {640,480,2048},
        {0,  480,2048}
    };
    for(int i = 0; i < sizeof(verts)/sizeof(verts[0]); i++) {
        struct glf3 *v = verts+i;
        const float KinectMinDistance = -10;
        const float KinectDepthScaleFactor = .0021f;
        v->x = (v->x - FREENECT_FRAME_W/2) * (v->z + KinectMinDistance) * KinectDepthScaleFactor ;
        v->y = (v->y - FREENECT_FRAME_H/2) * (v->z + KinectMinDistance) * KinectDepthScaleFactor ;
        v->z = 200 - v->z;
    }
    GLubyte inds[] = {0,1, 1,2 , 2,3, 3,0,   4,5, 5,6, 6,7, 7,4, 0,4,   1,5, 2,6, 3, 7}; // front, back, side
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    glColor4f(1, 1, 1, 0.5);
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(3, GL_FLOAT, sizeof(verts[0]), &verts->x); 
    glDrawElements(GL_LINES, sizeof(inds)/sizeof(inds[0]), GL_UNSIGNED_BYTE, inds);
    glDisableClientState(GL_VERTEX_ARRAY);
    
    glDisable(GL_BLEND);
}


- (void)drawScene {
    [ctrl viewFrame];
	
    NSSize size = [self bounds].size;
    int mode = [ctrl mode];
    
	
    uint16_t *depths = [ctrl createDepthData];
    if(depths) {
        
		for(int i = 0; i < (FREENECT_FRAME_W * FREENECT_FRAME_H); i++) {
			if((i < FREENECT_FRAME_W) || (fmod(i, FREENECT_FRAME_W) == 0) || (i > (FREENECT_FRAME_W * (FREENECT_FRAME_H - [ctrl getDetail] - 1))) || (fmod(i, FREENECT_FRAME_W) > (FREENECT_FRAME_W - [ctrl getDetail] - 1))) depths[i] = [ctrl getMax];
			if(depths[i] > [ctrl getMax]) depths[i] = [ctrl getMax];
			if(depths[i] < [ctrl getMin]) depths[i] = [ctrl getMin];// depth[i-1];
		}

		
        if(mode == MODE_MESH) {
            // naive - most common GPUs will start too choke when pushing 640x480 different triangles each frame.. (2009)
//            const float md = 5; // tolerance in z, increase to join more mesh triangles
            _nTriIndicies = 0;
			int stepx = [ctrl getDetail], stepy = [ctrl getDetail];
			
            for(int x = 0; x < FREENECT_FRAME_W-stepx; x = x + stepx) {
                for(int y = 0; y < FREENECT_FRAME_H-stepy; y = y + stepy) {
                    int idx = x+y*FREENECT_FRAME_W;
                    
                    int d = depths[idx];

                    if(d > 1 && d < 1800) {
						/*
                        int d01 = depth[idx+FREENECT_FRAME_W];
                        int d10 = depth[idx+1];
                        int d11 = depth[idx+FREENECT_FRAME_W+1];
						
                        float z = (100.0/(-0.00307 * d + 3.33));
                        float z01 = (d01 > 1.0 && d01 < 1800.0) ? (100.0/(-0.00307 * d01 + 3.33)) : 100000.0;
                        float z10 = (d10 > 1.0 && d10 < 1800.0) ? (100.0/(-0.00307 * d10 + 3.33)) : 100000.0;
                        float z11 = (d11 > 1.0 && d11 < 1800.0) ? (100.0/(-0.00307 * d11 + 3.33)) : 100000.0;
                        */
						
                        //if(fabsf(z01-z) < md && fabsf(z10-z) < md && fabsf(z11-z) < md) {
							//if((depth[idx] > [ctrl getMin]) && (depth[idx] < [ctrl getMax]) ) {
								_indicies[_nTriIndicies++] = idx;
								_indicies[_nTriIndicies++] = idx+stepx;
								_indicies[_nTriIndicies++] = idx+stepx+FREENECT_FRAME_W*stepy;
								_indicies[_nTriIndicies++] = idx;
								_indicies[_nTriIndicies++] = idx+stepx+FREENECT_FRAME_W*stepy;
								_indicies[_nTriIndicies++] = idx+FREENECT_FRAME_W*stepy;
							//}
                        //}
                    }
                }
            }
		}
		
		
		
        glActiveTexture(GL_TEXTURE1);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, FREENECT_FRAME_W, FREENECT_FRAME_H, GL_LUMINANCE, GL_UNSIGNED_SHORT, depths);
        glActiveTexture(GL_TEXTURE0);
        free(depths);
    }
    
    uint8_t *video = [ctrl createVideoData];        
    if(video) {
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, FREENECT_FRAME_W, FREENECT_FRAME_H, GL_RGB, GL_UNSIGNED_BYTE, video);
        free(video);
    }
    
    glClearColor(0.0, 0.0, 0.0, 1.0);    
    glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
    
    if(mode == MODE_POINTS || mode == MODE_MESH) {
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluPerspectivef(40, size.width/size.height, 0.05, 1000);
        
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        glTranslatef(_offset[0], _offset[1], -_offset[2]);
        glRotatef(_angle, 0, 1, 0);
        glRotatef(_tilt, -1, 0, 0);
        
        float s = 0.02;
        glScalef([ctrl mirror]?-s:s, -s, s); // flip y,  flipping the scene x is an incredibly stupid way to mirror
        
        glEnable(GL_DEPTH_TEST);
        
        glEnable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE2);
        glEnable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glEnable(GL_TEXTURE_2D);
        
        [_pointProgram bind];
        [_pointProgram setUniformInt:([ctrl normals]?1:0) forName:@"normals"];
        [_pointProgram setUniformInt:([ctrl natural]?1:0) forName:@"natural"];
        [_pointProgram setUniformFloat:[ctrl videoScale] forName:@"kColorScale"];
        [_pointProgram setUniformFloat:[ctrl videoX] forName:@"kColorX"];
        [_pointProgram setUniformFloat:[ctrl videoY] forName:@"kColorY"];
        
        glEnableClientState(GL_VERTEX_ARRAY);
        glBindBuffer(GL_ARRAY_BUFFER, _pointBuffer);
        glVertexPointer(2, GL_FLOAT, 0, NULL);
        if(mode == MODE_POINTS) {
            glDrawArrays(GL_POINTS, 0, FREENECT_FRAME_W*FREENECT_FRAME_H);
        } else {
            glDrawElements(GL_TRIANGLES, _nTriIndicies, GL_UNSIGNED_INT, _indicies);
        }
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glDisableClientState(GL_VERTEX_ARRAY);
        
        [_pointProgram unbind]; 
        
        glActiveTexture(GL_TEXTURE2);
        glDisable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glDisable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE0);
        glDisable(GL_TEXTURE_2D);
        
        [self drawFrustrum];
        
    } else {
        // ortho
        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        glOrtho(0.0f, size.width, size.height, 0.0f, -1.0f, 1.0f); // y-flip
        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
        
        glDisable(GL_DEPTH_TEST);
        
        glColor4f(1.0, 1.0, 1.0, 1.0);
        BOOL mirror = [ctrl mirror];
        
        // draw rgb
        
        glEnable(GL_TEXTURE_2D);
        glBegin(GL_QUADS);
        glTexCoord2f(mirror?1:0, 0); glVertex2f(0,               0);
        glTexCoord2f(mirror?0:1, 0); glVertex2f(FREENECT_FRAME_W,0);
        glTexCoord2f(mirror?0:1, 1); glVertex2f(FREENECT_FRAME_W,FREENECT_FRAME_H);
        glTexCoord2f(mirror?1:0, 1); glVertex2f(0,FREENECT_FRAME_H);
        glEnd();
        glDisable(GL_TEXTURE_2D);
        
        
        
        glTranslatef(FREENECT_FRAME_W, 0, 0);
        
        // draw depth
        glEnable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE2);
        glEnable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glEnable(GL_TEXTURE_2D);
        
        [_depthProgram bind];
        [_depthProgram setUniformInt:([ctrl normals]?1:0) forName:@"normals"];
        [_depthProgram setUniformInt:([ctrl natural]?1:0) forName:@"natural"];
        [_depthProgram setUniformFloat:[ctrl videoScale] forName:@"kColorScale"];
        [_depthProgram setUniformFloat:[ctrl videoX] forName:@"kColorX"];
        [_depthProgram setUniformFloat:[ctrl videoY] forName:@"kColorY"];
        
        glBegin(GL_QUADS);
        glTexCoord2f(mirror?1:0, 0); glVertex2f(0,               0);
        glTexCoord2f(mirror?0:1, 0); glVertex2f(FREENECT_FRAME_W,0);
        glTexCoord2f(mirror?0:1, 1); glVertex2f(FREENECT_FRAME_W,FREENECT_FRAME_H);
        glTexCoord2f(mirror?1:0, 1); glVertex2f(0,FREENECT_FRAME_H);
        glEnd();
        
        [_depthProgram unbind]; 
        
        glActiveTexture(GL_TEXTURE2);
        glDisable(GL_TEXTURE_1D);
        glActiveTexture(GL_TEXTURE1);
        glDisable(GL_TEXTURE_2D);
        glActiveTexture(GL_TEXTURE0);
        glDisable(GL_TEXTURE_2D);
        
    }
		
		
    GLint e = glGetError();
    if(e != 0) NSLog(@"GLERROR: %04x", e);
}


#pragma mark event handling

- (BOOL)acceptsFirstResponder { return YES; }

- (void)mouseDown:(NSEvent*)event {
    _lastPos = [self convertPoint:[event locationInWindow] fromView:nil];	
}

- (void)mouseDragged:(NSEvent*)event {
    if([ctrl mode] == MODE_2D) return;
    NSPoint pos = [self convertPoint:[event locationInWindow] fromView:nil];
    NSPoint delta = NSMakePoint((pos.x-_lastPos.x)/[self bounds].size.width, (pos.y-_lastPos.y)/[self bounds].size.height);
    _lastPos = pos;
    
    if([event modifierFlags] & NSShiftKeyMask) {
        _offset[0] += 2*delta.x;
        _offset[1] += 2*delta.y;
    } else {
        _angle += 50*delta.x;
        _tilt  += 50*delta.y;
    }
}

- (void)scrollWheel:(NSEvent *)event {
    if([ctrl mode] == MODE_2D) return;
    float d = ([event modifierFlags] & NSShiftKeyMask) ? [event deltaX] : [event deltaY];
    _offset[2] += d*0.1;
    if(_offset[2] < 0.5) _offset[2] = 0.5;
}

- (void)keyDown:(NSEvent *)event {
    if([ctrl mode] == MODE_2D) return;
    unichar key = [[event charactersIgnoringModifiers] characterAtIndex:0];
    switch(key) {
        case 'c': case 'C':
            _angle = 0;
            _tilt  = 0;
            break;
        case 'z': case 'Z':
            _offset[0] = 0;
            _offset[1] = 0;
            _offset[2] = 5;
            break;
        case NSLeftArrowFunctionKey:  _offset[0]-=0.1; break;
        case NSRightArrowFunctionKey: _offset[0]+=0.1; break;
        case NSDownArrowFunctionKey:  _offset[1]-=0.1; break;
        case NSUpArrowFunctionKey:    _offset[1]+=0.1; break;
    }
}

@end
