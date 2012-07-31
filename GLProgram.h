//  Created by fernlightning on 27/11/2010.

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

@interface GLProgram : NSObject {
    GLuint _id;
    NSString *_name;
}
- (id)initWithName:(NSString*)name VS:(const char*)vs FS:(const char*)fs;

- (NSString*)name;

- (void)bind;
- (void)unbind;

- (void)setUniformInt:(int)i forName:(NSString*)name;
- (void)setUniformFloat:(float)f forName:(NSString*)name;
@end
