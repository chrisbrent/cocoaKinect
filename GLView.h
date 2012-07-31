//  Created by fernlightning on 18/11/2010.

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGL/OpenGL.h>

@class AppDelegate;

@class GLProgram;

@interface GLView : NSOpenGLView {
    IBOutlet AppDelegate *ctrl;
    
    CVDisplayLinkRef _displayLink;
    
    GLuint _depthTex, _videoTex, _colormapTex;
    GLuint _pointBuffer;
    
    GLuint *_indicies;
    int _nTriIndicies;
    
    GLProgram *_pointProgram;
    GLProgram *_depthProgram;
    
    // 3D navigation
    NSPoint _lastPos;
    float _offset[3];
    float _angle, _tilt;

}

@end
