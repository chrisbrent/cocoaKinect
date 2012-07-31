//  Created by fernlightning on 18/11/2010.

#import <Cocoa/Cocoa.h>
#import "libfreenect.h"
#import <CoreVideo/CoreVideo.h>

typedef struct {
	float x;
	float y;
	float z;
} VectorP;

@interface AppDelegate : NSObject <NSApplicationDelegate> {    
	
	
    freenect_device *_device;
    BOOL _halt;
    
    NSString *_status;
    
    uint16_t *_depthBack, *_depthFront;
    BOOL _depthUpdate;
    
    uint8_t *_videoBack, *_videoFront;
    BOOL _videoUpdate;
    
	float depthLookUp[2048];
	
    int _depthCount, _videoCount, _viewCount;
    float _depthFps, _videoFps, _viewFps;
    NSDate *_lastPollDate;
    
    int _led;
    float _tilt;
	float _snapdelay;
	int _minDepth;
	int _maxDepth;
	int _detailSlide;
	int _progressValue;
	
    BOOL _ir;
	BOOL _background;
    BOOL _normals;
    BOOL _mirror;
    BOOL _natural;
    enum drawMode {
        MODE_MESH=0,
        MODE_POINTS=1,
        MODE_2D=2,
    } _mode; 
		
    float _videoScale;
    float _videoX;
    float _videoY;
	
    IBOutlet NSSlider *stupidvideoScaleSlider;
}

- (IBAction)play:(id)sender; // toggle between start/stop
- (IBAction)savePly:(id)sender; // toggle between start/stop
- (IBAction)saveSTL:(id)sender; // toggle between start/stop
- (IBAction)saveSTLB:(id)sender;

// return NULL if no new data - must free the result
- (uint16_t*)createDepthData;
- (uint8_t*)createVideoData;

- (void)viewFrame; // callback from view to say that it showed a frame (for fps calc purposes only)

@property int led; //0..6
@property float tilt; // +/- 30
@property float snapdelay; // +/- 30
@property int minDepth; // +/- 30
@property int maxDepth; // +/- 30
@property int detailSlide; // +/- 30
@property int progressValue;
@property float videoFps;
@property float depthFps;
@property float viewFps;
@property(retain) NSString* status;
@property BOOL ir;
@property BOOL background;
@property BOOL normals;
@property BOOL mirror;
@property BOOL natural;
@property enum drawMode mode; // 0=2d, 1=points, 2=mesh
@property float videoScale;
@property float videoX;
@property float videoY;

- (double)getMin;
- (double)getMax;
- (double)rawDepthToMeters:(int) depthValue;
- (int) getDetail;

- (NSMutableString*) stringVector:(VectorP*)poly;
- (NSMutableData*) binaryVector:(VectorP*)poly;


void calcNormal(VectorP *poly);
VectorP toWorld(int x, int y, double depths);

- (CVPixelBufferRef)createVideoBuffer;
- (CVPixelBufferRef)createDepthBuffer;

@end
