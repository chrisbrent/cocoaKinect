//  Created by fernlightning on 18/11/2010.

#import "AppDelegate.h"
#import "GLView.h"

@interface AppDelegate()
- (void)depthCallback:(uint16_t*)depth;
- (void)rgbCallback:(uint8_t*)video;
- (void)irCallback:(uint8_t*)ir;
@end


static void depthCallback(freenect_device *dev, void *depth, uint32_t timestamp) {
    [(AppDelegate *)freenect_get_user(dev) depthCallback:(uint16_t*)depth];
}
static void rgbCallback(freenect_device *dev, void *video, uint32_t timestamp) {
    [(AppDelegate *)freenect_get_user(dev) rgbCallback:(uint8_t*)video];
}
static void irCallback(freenect_device * dev, void *video, uint32_t timestamp) {
    [(AppDelegate *)freenect_get_user(dev) irCallback:(uint8_t*)video];
}

@implementation AppDelegate

- (void)stopIO {
    _halt = YES;
    while(_device != NULL) usleep(10000); // crude
}

- (void)startIO {
    [self setStatus:@"Starting"];
    _halt = NO;
    [NSThread detachNewThreadSelector:@selector(ioThread) toTarget:self withObject:nil];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [stupidvideoScaleSlider setMaxValue:0.005]; // because IB won't let you set a maxvalue this small
    
    // @TODO - store these in a preference file
    [self setVideoScale:0.0023];
    [self setVideoX:-2.43];
    [self setVideoY: 6.78];
    
    _depthFront = (uint16_t*)malloc(FREENECT_DEPTH_11BIT_SIZE);
    _depthBack = (uint16_t*)malloc(FREENECT_DEPTH_11BIT_SIZE);
    _videoFront = (uint8_t*)malloc(FREENECT_VIDEO_RGB_SIZE);
    _videoBack = (uint8_t*)malloc(FREENECT_VIDEO_RGB_SIZE);
    
	[self setMinDepth:0];
	[self setMaxDepth:760];
	[self setSnapdelay:0];
	[self setDetailSlide:6];
	[self setBackground:YES];	
	
    _lastPollDate = [[NSDate date] retain];
    [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(pollFps) userInfo:nil repeats:YES];
        
	
	for (int i = 0; i < 2048; i++) {
		depthLookUp[i] = [self rawDepthToMeters:i];
	}
	
    [self startIO];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self stopIO];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    return YES;
}

- (IBAction)play:(id)sender {
    if(_device) {
        [self stopIO];
    } else {
        [self startIO];
    }
}


- (double)rawDepthToMeters:(int) depthValue {
	if(depthValue < _minDepth) depthValue = _minDepth;
	if(depthValue > _maxDepth) depthValue = _maxDepth;
	
	if (depthValue < 2047) {
		return (double)(1.0 / ((double)(depthValue) * -0.0030711016 + 3.3309495161));
	}
	return 0.0f;
}
- (double)getMin {
	return _minDepth;
}
- (double)getMax {
	return _maxDepth;
}

VectorP toWorld(int x, int y, double depths) {
	VectorP temp;
	double fx_d = 1.0 / 5.9421434211923247e+02;
	double fy_d = 1.0 / 5.9104053696870778e+02;
	double cx_d = 3.3930780975300314e+02;
	double cy_d = 2.4273913761751615e+02;
	
	temp.y = (float)((y - cy_d) * depths * fy_d) * 80;
	temp.x = (float)((x - cx_d) * depths * fx_d) * 80;
	temp.z = (float)((-1) * depths) * 80;
	
	return temp;
}

void calcNormal(VectorP *poly) {
	VectorP temp;
	float fac1;
	
	temp.x = (poly[2].y-poly[0].y)*(poly[1].z-poly[0].z)-(poly[1].y-poly[0].y)*(poly[2].z-poly[0].z);
	temp.y = (poly[2].z-poly[0].z)*(poly[1].x-poly[0].x)-(poly[1].z-poly[0].z)*(poly[2].x-poly[0].x);
	temp.z = (poly[2].x-poly[0].x)*(poly[1].y-poly[0].y)-(poly[1].x-poly[0].x)*(poly[2].y-poly[0].y);
	fac1 = sqrt((temp.x*temp.x)+(temp.y*temp.y)+(temp.z*temp.z));
	temp.x = temp.x/fac1;
	temp.y = temp.y/fac1;
	temp.z = temp.z/fac1;
	
	poly[3] = temp;
}

- (NSMutableString*) stringVector:(VectorP*)poly {
	NSMutableString *temp = [[[NSMutableString alloc] init] autorelease];
	[temp appendString:@"   facet normal "];
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[3].x]];
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[3].y]];
	[temp appendString:[NSString stringWithFormat:@"%e\n", poly[3].z]];
	
	[temp appendString:@"      outer loop\n"];
	
	[temp appendString:@"         vertex "];					
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[0].x]];
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[0].y]];
	[temp appendString:[NSString stringWithFormat:@"%e\n",   poly[0].z]];
	
	[temp appendString:@"         vertex "];
	
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[1].x]];
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[1].y]];
	[temp appendString:[NSString stringWithFormat:@"%e\n", poly[1].z]];
	
	[temp appendString:@"         vertex "];
	
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[2].x]];
	[temp appendString:[NSString stringWithFormat:@"%e ", poly[2].y]];
	[temp appendString:[NSString stringWithFormat:@"%e\n",  poly[2].z]];
	
	[temp appendString:@"      endloop\n"];					
	[temp appendString:@"   endfacet\n"];
	
	return temp;
}

- (NSMutableData*) binaryVector:(VectorP[])poly {
	NSMutableData *temp = [[NSMutableData alloc] autorelease];
	double nullb = 0x00;
	
	[temp appendBytes:&poly[3].x length:4];
	[temp appendBytes:&poly[3].y length:4];
	[temp appendBytes:&poly[3].z length:4];
	[temp appendBytes:&poly[0].x length:4];
	[temp appendBytes:&poly[0].y length:4];
	[temp appendBytes:&poly[0].z length:4];
	[temp appendBytes:&poly[1].x length:4];
	[temp appendBytes:&poly[1].y length:4];
	[temp appendBytes:&poly[1].z length:4];
	[temp appendBytes:&poly[2].x length:4];
	[temp appendBytes:&poly[2].y length:4];
	[temp appendBytes:&poly[2].z length:4];
	[temp appendBytes:&nullb length:2];
	
	return temp;
}

- (IBAction)savePly:(id)sender {
    int depthAttempt = 0;
	VectorP tempVector;
	NSMutableString *PLYFile;
		
	[NSThread sleepForTimeInterval:_snapdelay];
	

	uint16_t *depth = [self createDepthData];
		while (!depth) {
			depth = [self createDepthData];
            depthAttempt++;
            NSLog(@"depth attempt number %d", depthAttempt);
		}
	if(depth) {
		int result;
		NSArray *fileTypes = [NSArray arrayWithObject:@"ply"];
		
		NSSavePanel *oPanel = [NSSavePanel savePanel];
		[oPanel setAllowedFileTypes:fileTypes];
		
		result = [oPanel runModal];
		if (result == NSOKButton) {
			NSString *aFile = [[oPanel URL] path];
		
			int stepx = _detailSlide, stepy = _detailSlide;
			
		int temp = 0;
		NSMutableString *temps = [[NSMutableString alloc] initWithString:@""];
		
		for(int x = 0; x < FREENECT_FRAME_W-stepx - 7; x = x + stepx) {
			for(int y = 0; y < FREENECT_FRAME_H-stepy; y = y + stepy) {
				int idx = x+y*FREENECT_FRAME_W;
				
				double dep = depthLookUp[depth[idx]];
					tempVector = toWorld(x, y, dep);
					[temps appendString:[NSString stringWithFormat:@"%f  ", tempVector.x]];
					[temps appendString:[NSString stringWithFormat:@"%f  ", tempVector.y]];
					[temps appendString:[NSString stringWithFormat:@"%f",   tempVector.z]];
					[temps appendString:@"\n"];
					temp += 1;
			}
		}
		PLYFile = [[NSMutableString alloc] initWithString:@""];
		[PLYFile appendString:@"ply\n"];
		[PLYFile appendString:@"format ascii 1.0\n"];
		[PLYFile appendString:@"comment : created from Kinect depth image\n"];
		[PLYFile appendString:@"element vertex "];
		[PLYFile appendString:[NSString stringWithFormat:@"%d", temp]];
		[PLYFile appendString:@"\n"];
		[PLYFile appendString:@"property float x\n"];
		[PLYFile appendString:@"property float y\n"];
		[PLYFile appendString:@"property float z\n"];
		[PLYFile appendString:@"end_header\n"];
		[PLYFile appendString:temps];
            NSError *error = nil;
            if(![PLYFile writeToFile:aFile atomically:YES encoding:NSASCIIStringEncoding error:&error]){
                if (error) {
                    NSLog(@"%@", error.localizedDescription);
                }
            }
	    }
	} else {

	}
}

- (int) getDetail {
	return _detailSlide;
}

- (IBAction)saveSTL:(id)sender {
	VectorP tempPoly[3];
    int depthAttempt = 0;
	
	NSMutableString *STLFile;
	
	[NSThread sleepForTimeInterval:_snapdelay];
	
	uint16_t *depth = [self createDepthData];
	while (!depth) {
		depth = [self createDepthData];
        depthAttempt++;
        NSLog(@"depth attempt number %d", depthAttempt);
	}
	if(depth) {
		int result;
		NSArray *fileTypes = [NSArray arrayWithObject:@"STL"];
		
		NSSavePanel *oPanel = [NSSavePanel savePanel];
		[oPanel setAllowedFileTypes:fileTypes];
		
		result = [oPanel  runModal];
		if (result == NSOKButton) {
			NSString *aFile = [[oPanel URL] path];
			
			NSMutableString *temps2 = [[NSMutableString alloc] initWithString:@""];
			for(int i = 0; i < (FREENECT_FRAME_W * FREENECT_FRAME_H); i++) {
				if((i < FREENECT_FRAME_W) || (fmod(i, FREENECT_FRAME_W) == 0) || (i > (FREENECT_FRAME_W * (FREENECT_FRAME_H - _detailSlide - 1))) || (fmod(i, FREENECT_FRAME_W) > (FREENECT_FRAME_W - _detailSlide - 1))) depth[i] = _maxDepth;
				
				
				if(depth[i] >  _maxDepth) depth[i] = _maxDepth;
				
				if(depth[i] < _minDepth) depth[i] = _minDepth;
			}
			//const float md = 5; // tolerance in z, increase to join more mesh triangles
						
			int stepx = _detailSlide, stepy = _detailSlide;
			
			for(int x = 0; x < FREENECT_FRAME_W-stepx; x = x + stepx) {
				_progressValue = x;
				for(int y = 0; y < FREENECT_FRAME_H-stepy; y = y + stepy) {
                    int idx = x+y*FREENECT_FRAME_W;
                    											
							
					tempPoly[0] = toWorld(x, y, depthLookUp[depth[idx]]);
					tempPoly[1] = toWorld(x+stepx, y, depthLookUp[depth[idx+stepx]]);
					tempPoly[2] = toWorld(x+stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy+stepx]]);
					calcNormal(tempPoly);
					
					[temps2 appendString:[self stringVector:tempPoly]];
					
							
					tempPoly[0] = toWorld(x, y, depthLookUp[depth[idx]]);
					tempPoly[1] = toWorld(x+stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy+stepx]]);
					tempPoly[2] = toWorld(x, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy]]);
					calcNormal(tempPoly);
										  
					[temps2 appendString:[self stringVector:tempPoly]];
				}
			}
			
			STLFile = [[NSMutableString alloc] initWithString:@"solid object\n"];
			
			[STLFile appendString:temps2];
			[STLFile appendString:@"endsolid"];
            NSError *error = nil;
            
			if(![STLFile writeToFile:aFile atomically:YES encoding:NSASCIIStringEncoding error:&error]){
                if(error){
                    NSLog(@"%@", error.localizedDescription);
                }
            }
			
			
		}
	} else {
		
	}
}


- (IBAction)saveSTLB:(id)sender {
	VectorP tempPoly[5];
		
	NSMutableData *STLBData;
	
	[NSThread sleepForTimeInterval:_snapdelay];
	
	NSUInteger *faceCount = 0;
	double nullb = 0x00;
	uint16_t *depth = [self createDepthData];
	
	while (!depth) {
		depth = [self createDepthData];
	}
	if(depth) {
		int result;
		NSArray *fileTypes = [NSArray arrayWithObject:@"STL"];
		
		NSSavePanel *oPanel = [NSSavePanel savePanel];
		[oPanel setAllowedFileTypes:fileTypes];
		/* Use -runModal after setting up desired properties. The following parameters are replaced by properties: 'path' is replaced by 'directoryURL' and 'name' by 'nameFieldStringValue'.
         */
        oPanel.directoryURL=nil;
		result = [oPanel runModal];
        
		if (result == NSOKButton) {
			NSString *aFile = [[oPanel URL] path];
			
			NSMutableData *temps2 = [[[NSMutableData alloc] init] autorelease];
			
			[self setMaxDepth:floor(_maxDepth)];
			
			int stepx = _detailSlide, stepy = _detailSlide;
			int i = 0, maxX = 0, maxY = 0;
			for(int y = 0; y < FREENECT_FRAME_H-1; y = y + stepy) {				
				for(int x = 0; x < FREENECT_FRAME_W-1; x = x + stepx) {
				i = x+y*FREENECT_FRAME_W;	
					
					//Smooth Depth Data
					depth[i] = (depth[i]
								+ depth[i+stepx] 
								+ depth[i+FREENECT_FRAME_W*stepy] 
								+ depth[i+FREENECT_FRAME_W*stepy+stepx]) /  4;
					
					//Check borders and make maxDepth
					if((y < stepy*3) 
					   || (x < stepx*3)
					   || (y > (FREENECT_FRAME_H - stepy*3))
					   || (x > (FREENECT_FRAME_W - stepx*3))) depth[i] = _maxDepth;
				
					//Limit Depth to maxDepth
					if(depth[i] >  _maxDepth) depth[i] = _maxDepth;
				
					//Limit Depth to minDepth
					if(depth[i] < _minDepth) depth[i] = _minDepth;
				}
			}
			
			//const float md = 5; // tolerance in z, increase to join more mesh triangles
			
			int foundFace = 0;
			int oidx = 0, fidx = 0;
			
			int idx = 0;

			//				for(temp = 0; temp < count; temp = temp + 6) {
			for(int y = stepy; y < FREENECT_FRAME_H-stepy-1; y = y + stepy) {
				[self setProgressValue:y];
				foundFace = 0;

				if (y > maxY) {
					maxY = y;
				}
				for(int x = stepx; x < FREENECT_FRAME_W-stepx-1; x = x + stepx) {
                    idx = x+y*FREENECT_FRAME_W;
					if (x > maxX) {
						maxX = x;
					}

					if((depth[idx+stepx*1] < _maxDepth)
					   || ((depth[idx+stepx*1+FREENECT_FRAME_W*stepy] < _maxDepth))
					   || (depth[idx] < _maxDepth)
					   || ((depth[idx+FREENECT_FRAME_W*stepy] < _maxDepth))) {
						
						tempPoly[0] = toWorld(x, y, depthLookUp[depth[idx]]);
						tempPoly[1] = toWorld(x+stepx, y, depthLookUp[depth[idx+stepx]]);
						tempPoly[2] = toWorld(x+stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy+stepx]]);
						calcNormal(tempPoly);
						
						[temps2 appendData:[self binaryVector:tempPoly]];
						
						
						tempPoly[0] = toWorld(x, y, depthLookUp[depth[idx]]);
						tempPoly[1] = toWorld(x+stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy+stepx]]);
						tempPoly[2] = toWorld(x, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy]]);
						calcNormal(tempPoly);
						
						[temps2 appendData:[self binaryVector:tempPoly]];
						
						
						faceCount = faceCount + 2;
					} else {
						if(_background == YES) {
							if(foundFace == 0) {
								fidx = idx;
								oidx = 1;
								foundFace = 1;
							} 

							if(((foundFace)
								&& ((depth[idx] >= _maxDepth)
								&& (depth[idx+FREENECT_FRAME_W*stepy] >= _maxDepth)
								&& (depth[idx+stepx*1] >= _maxDepth)
								&& (depth[idx+stepx*1+FREENECT_FRAME_W*stepy] >= _maxDepth))
							   
								&& ((depth[idx+stepx*2] < _maxDepth)
								|| (depth[idx+stepx*2+FREENECT_FRAME_W*stepy] < _maxDepth)))
							   
								|| (x >= FREENECT_FRAME_W - stepx*2 - 1)) {
									
								idx = fidx;
								
								oidx = oidx * stepx;
									
								tempPoly[0] = toWorld(x-oidx+ stepx, y, depthLookUp[depth[idx]]);
								tempPoly[1] = toWorld(x+ stepx, y, depthLookUp[depth[idx+oidx]]);
								tempPoly[2] = toWorld(x+ stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy+oidx]]);
								calcNormal(tempPoly);
								
								[temps2 appendData:[self binaryVector:tempPoly]];
								
								
								tempPoly[0] = toWorld(x-oidx+ stepx, y, depthLookUp[depth[idx]]);
								tempPoly[1] = toWorld(x+ stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy+oidx]]);
								tempPoly[2] = toWorld(x-oidx+ stepx, y+stepy, depthLookUp[depth[idx+FREENECT_FRAME_W*stepy]]);
								calcNormal(tempPoly);
								
								[temps2 appendData:[self binaryVector:tempPoly]];
							
									faceCount = faceCount + 2;
									oidx = 0;
									foundFace = 0;
							}
								oidx++;
						}
					}
				}
			}
			
			int x;			
			x = stepx;
			tempPoly[0] = toWorld(x, stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			// Create a Box
			
			for(int y = stepy; y < FREENECT_FRAME_H-stepy-1; y = y + stepy) {
				tempPoly[2] = toWorld(x, y + stepy, depthLookUp[_maxDepth]);
				tempPoly[1] = toWorld(x, y, depthLookUp[_maxDepth]);
				calcNormal(tempPoly);
				[temps2 appendData:[self binaryVector:tempPoly]];
				
				faceCount = faceCount + 1;
			}
			
			x = maxX;
			tempPoly[0] = toWorld(x + stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			// Create a Box
			
			for(int y = stepy; y < FREENECT_FRAME_H-stepy-1; y = y + stepy) {
				tempPoly[1] = toWorld(x + stepx, y + stepy, depthLookUp[_maxDepth]);
				tempPoly[2] = toWorld(x + stepx, y, depthLookUp[_maxDepth]);
				calcNormal(tempPoly);
				[temps2 appendData:[self binaryVector:tempPoly]];
				
				faceCount = faceCount + 1;
			}

			
			//Rear Face
			tempPoly[2] = toWorld(stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(maxX + stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[0] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			tempPoly[1].z -= 5;
			tempPoly[2].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];
			tempPoly[2] = toWorld(stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[0] = toWorld(stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			tempPoly[1].z -= 5;
			tempPoly[2].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];

			//Botom Face
			tempPoly[0] = toWorld(stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(maxX + stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[2] = toWorld(maxX + stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			tempPoly[1].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];
			//Check Good
			tempPoly[0] = toWorld(stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(maxX + stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[2] = toWorld(stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];

			//Botom Face
			tempPoly[0] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[2] = toWorld(stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			tempPoly[1].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];
			//Check Good
			tempPoly[0] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[2] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[0].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];
			
			//Complete Left
			tempPoly[2] = toWorld(stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[0] = toWorld(stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[2].z -= 5;
			tempPoly[1].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];
			
			//Complete Left
			tempPoly[2] = toWorld(maxX + stepx, stepy, depthLookUp[_maxDepth]);
			tempPoly[0] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[1] = toWorld(maxX + stepx, maxY + stepy, depthLookUp[_maxDepth]);
			tempPoly[2].z -= 5;
			tempPoly[0].z -= 5;
			calcNormal(tempPoly);
			[temps2 appendData:[self binaryVector:tempPoly]];
			
			faceCount = faceCount + 8;
			
			STLBData = [[[NSMutableData alloc] init] autorelease];
			for(int o = 0; o < 20; o++) {
				[STLBData appendBytes:&nullb length:4];				//Blank Header
			}
			[STLBData appendBytes:&faceCount length:4];								//Number of Facets
			
			[STLBData appendData:temps2];
			if(![STLBData writeToFile:aFile atomically:YES]){
                NSLog(@"Writing to %@ failed.", aFile);
            }
		}
	} else {
		
	}
}

- (void)safeSetStatus:(NSString*)status {
    [self performSelectorOnMainThread:@selector(setStatus:) withObject:status waitUntilDone:NO];
}

- (void)ioThread {
    freenect_context *_context;
    if(freenect_init(&_context, NULL) >= 0) {
        if(freenect_num_devices(_context) == 0) {
            [self safeSetStatus:@"No device"];
        } else if(freenect_open_device(_context, &_device, 0) >= 0) {
            freenect_set_user(_device, self);
            freenect_set_depth_callback(_device, depthCallback);
            freenect_set_video_callback(_device, rgbCallback);
            freenect_set_video_format(_device, FREENECT_VIDEO_RGB);
            freenect_set_depth_format(_device, FREENECT_DEPTH_11BIT);
            freenect_start_depth(_device);
            freenect_start_video(_device);
            
            [self safeSetStatus:@"Running"];
            
            BOOL lastIr = NO;
            int lastLed = 0;
            float lastTilt = 0;
			
            while(!_halt && freenect_process_events(_context) >= 0) {
            
                if(_ir != lastIr) {
                    lastIr = _ir;
                    freenect_stop_video(_device);
                    freenect_set_video_callback(_device, lastIr?irCallback:rgbCallback);
                    freenect_set_video_format(_device,   lastIr?FREENECT_VIDEO_IR_8BIT:FREENECT_VIDEO_RGB);
                    freenect_start_video(_device);                    
                }
                
                if(_led != lastLed) {
                    lastLed = _led;
                    freenect_set_led(_device, lastLed);
                }
                
                if(_tilt != lastTilt) {
                    lastTilt = _tilt;
                    freenect_set_tilt_degs(_device, lastTilt);
                }
                
                /*
                freenect_update_device_state(f_dev);
                freenect_raw_device_state *state = freenect_get_device_state(f_dev);
                double dx,dy,dz;
                freenect_get_mks_accel(state, &dx, &dy, &dz);
                */
            }
            
            freenect_close_device(_device);
            _device = NULL;
            
            [self safeSetStatus:@"Stopped"];
        } else {
            [self safeSetStatus:@"Could not open device"];
        }
        freenect_shutdown(_context);
    } else {
		[self safeSetStatus:@"Could not init device"];
	}    
}

- (void)depthCallback:(uint16_t *)buffer {
    // update back buffer, then when safe swap with front
    memcpy(_depthBack, buffer, FREENECT_DEPTH_11BIT_SIZE);
    @synchronized(self) {
        uint16_t *dest = _depthBack;
        _depthBack = _depthFront;
        _depthFront = dest;
        _depthCount++;
        _depthUpdate = YES;
    }
}

- (void)rgbCallback:(uint8_t *)buffer {
    // update back buffer, then when safe swap with front
    memcpy(_videoBack, buffer, FREENECT_VIDEO_RGB_SIZE);
    @synchronized(self) {
        uint8_t *dest = _videoBack;
        _videoBack = _videoFront;
        _videoFront = dest;
        _videoCount++;
        _videoUpdate = YES;
    }
}

- (void)irCallback:(uint8_t *)buffer {
    // update back buffer, then when safe swap with front
    for (int i = 0; i < FREENECT_FRAME_PIX; i++) {
        int pval = buffer[i];
        _videoBack[3 * i + 0] = pval;
        _videoBack[3 * i + 1] = pval;
        _videoBack[3 * i + 2] = pval;        
    }
    @synchronized(self) {
        uint8_t *dest = _videoBack;
        _videoBack = _videoFront;
        _videoFront = dest;
        _videoCount++;
        _videoUpdate = YES;
    }
}


- (uint16_t*)createDepthData {
    // safely return front buffer, create a new buffer to take it's place
    uint16_t *src = NULL;
    @synchronized(self) {
        if(_depthUpdate) {
            _depthUpdate = NO;
            src = _depthFront;
            _depthFront = (uint16_t*)malloc(FREENECT_DEPTH_11BIT_SIZE);
        }
    }
    return src;
}

- (uint8_t*)createVideoData {
    // safely return front buffer, create a new buffer to take it's place
    uint8_t *src = NULL;
    @synchronized(self) {
        if(_videoUpdate) {
            _videoUpdate = NO;
            src = _videoFront;
            _videoFront = (uint8_t*)malloc(FREENECT_VIDEO_RGB_SIZE);
        }
    }
    return src;
}

- (void)viewFrame {
    @synchronized(self) {
        _viewCount++;
    }
}

- (void)pollFps {
    NSDate *date = [NSDate date];
    NSTimeInterval t = -[_lastPollDate timeIntervalSinceDate:date];
    if(t > 0.5) {
        [_lastPollDate release];
        _lastPollDate = [date retain];
        
        int videoc, depthc, viewc;
        @synchronized(self) {
            videoc = _videoCount;
            depthc = _depthCount;
            viewc = _viewCount;
            _videoCount = 0;
            _depthCount = 0;
            _viewCount = 0;
        }
        [self setVideoFps:videoc/t];
        [self setDepthFps:depthc/t];
        [self setViewFps:viewc/t];
    }
}

@synthesize depthFps = _depthFps;
@synthesize videoFps = _videoFps;
@synthesize viewFps = _viewFps;

@synthesize tilt = _tilt;
@synthesize snapdelay = _snapdelay;
@synthesize detailSlide = _detailSlide;
@synthesize minDepth = _minDepth;
@synthesize maxDepth = _maxDepth;
@synthesize led = _led;

@synthesize status = _status;

@synthesize ir = _ir;
@synthesize background = _background;

@synthesize normals = _normals;
@synthesize mirror = _mirror;
@synthesize natural = _natural;
@synthesize mode = _mode;
@synthesize progressValue = _progressValue;

@synthesize videoScale = _videoScale;
@synthesize videoX = _videoX;
@synthesize videoY = _videoY;

// when in IR mode dont transform the video coords
- (float)videoScale { return _ir?0.0021:_videoScale; } // match kDepthScale
- (float)videoX { return _ir?0.0:_videoX; }
- (float)videoY { return _ir?0.0:_videoY; }

#pragma mark corevideo output (unused)

static void releasePbufferMemory(void *releaseRefCon, const void *baseAddress) {
    free((void*)baseAddress);
}

- (CVPixelBufferRef)createVideoBuffer {
    // maybe use a CVPixelBufferPoolRef and memcpy into the buffers...
    void *baseAddress = [self createVideoData];
    if(!baseAddress) return NULL;
    
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:YES], kCVPixelBufferOpenGLCompatibilityKey,
        nil];    
    
    const int bpr = FREENECT_FRAME_W*3;

    CVPixelBufferRef pbuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, FREENECT_FRAME_W, FREENECT_FRAME_H, k24RGBPixelFormat, baseAddress, bpr,
					       releasePbufferMemory, NULL,
					       (CFDictionaryRef)attrs, 
                           &pbuffer);
    if(status != kCVReturnSuccess || pbuffer == NULL) NSLog(@"Failed createVideoBuffer %d", status);
    return pbuffer;
}

- (CVPixelBufferRef)createDepthBuffer {
    // maybe use a CVPixelBufferPoolRef and memcpy into the buffers...
    uint16_t *baseAddress = [self createDepthData];
    if(!baseAddress) return NULL;
    
    NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithBool:YES], kCVPixelBufferOpenGLCompatibilityKey, // but cant seem to turn kCVPixelFormatType_16Gray back into an opengl texture
        nil];    
    
    const int bpr = FREENECT_FRAME_W*2;
    
    CVPixelBufferRef pbuffer = NULL;
    CVReturn status = CVPixelBufferCreateWithBytes(kCFAllocatorDefault, FREENECT_FRAME_W, FREENECT_FRAME_H, kCVPixelFormatType_16Gray, baseAddress, bpr,
					       releasePbufferMemory, NULL,
					       (CFDictionaryRef)attrs, 
                           &pbuffer);
    if(status != kCVReturnSuccess || pbuffer == NULL) NSLog(@"Failed createDepthBuffer %d", status);
    return pbuffer;
}

@end
