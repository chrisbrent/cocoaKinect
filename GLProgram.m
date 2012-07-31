//  Created by fernlightning on 27/11/2010.

#include </Developer/SDKs/MacOSX10.7.sdk/System/Library/Frameworks/OpenGL.framework/Versions/A/Headers/gl3.h>
#include </Developer/SDKs/MacOSX10.7.sdk/System/Library/Frameworks/OpenGL.framework/Versions/A/Headers/glu.h>

#import "GLProgram.h"

@implementation GLProgram

-(GLuint)loadShader:(GLenum)type code:(const char *)code {
    NSString *desc = [NSString stringWithFormat:@"%@ shader %@", ((type == GL_VERTEX_SHADER)?@"Vertex":@"Fragment"), _name];
    GLuint shader = glCreateShader(type);	
	glShaderSource(shader, 1, (const GLchar **)&code, NULL);
	glCompileShader(shader);
	
    GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
	if(logLength > 0) {
		GLchar *log = malloc(logLength);
		glGetShaderInfoLog(shader, logLength, &logLength, log);
		NSLog(@"%@ compile log:\n%s", desc, log);
		free(log);
	}
    
    GLint status;
	glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
	if(status == 0)
		NSLog(@"Failed to compile desc: %@ : %s", desc, code);
    
	return shader;
}

- (id)initWithName:(NSString*)name VS:(const char*)vs FS:(const char*)fs {
    if((self = [super init])) {
        _name = [name retain];
        
        NSString *desc = [NSString stringWithFormat:@"Program %@", _name];
        GLuint cvs = [self loadShader:GL_VERTEX_SHADER code:vs];
        GLuint cfs = [self loadShader:GL_FRAGMENT_SHADER code:fs];
        _id = glCreateProgram();
        glAttachShader(_id, cvs);
        glAttachShader(_id, cfs);
        glLinkProgram(_id);
        
        GLint logLength;
        glGetProgramiv(_id, GL_INFO_LOG_LENGTH, &logLength);
        if(logLength > 0) {
            GLchar *log = malloc(logLength);
            glGetProgramInfoLog(_id, logLength, &logLength, log);
            NSLog(@"%@ link log:\n%s", desc, log);
            free(log);
        }
        
        GLint status;
        glGetProgramiv(_id, GL_LINK_STATUS, &status);
        if(status == 0) {
            NSLog(@"Failed to link %@", desc);
        }
        
        glDeleteShader(cvs);
        glDeleteShader(cfs);
    }
    return self;
}

- (void)dealloc {
    [_name release];
    glDeleteProgram(_id);
    [super dealloc];
}

- (NSString*)name { return _name; }

- (void)bind {
    glUseProgram(_id);
}

- (void)unbind {
    glUseProgram(0);
}

- (GLint)uniformLocation:(NSString*)name {
    GLint location = glGetUniformLocation(_id, [name UTF8String]);
    if(location < 0)  NSLog(@"No such uniform named %@ in %@\n", name, _name);
    return location;
}

- (void)setUniformInt:(int)i forName:(NSString*)name {
    glUniform1i([self uniformLocation:name], i);
}
- (void)setUniformFloat:(float)f forName:(NSString*)name {
    glUniform1f([self uniformLocation:name], f);
}

@end
