//
//  app.m
//  AutoScroll
//
//  Created by Steven G on 8/20/23.
//

#import "app.h"
#import "globals.h"
#import "autoscroll.h"
#import "helperLib.h"

CFMachPortRef mousedownEventTapRef;
CFMachPortRef mouseupEventTapRef;
CFMachPortRef mousemoveEventTapRef;

@implementation app
+ (void) mousedown: (CGEventRef) e : (CGEventType) etype {
    
}
+ (void) mouseup: (CGEventRef) e : (CGEventType) etype {
    
}
+ (void) mousemove: (CGEventRef) e : (CGEventType) etype {
    
}
+ (void) init {
    [autoscroll init];
    [self startListening]; //cgeventtap
}
+ (void) startListening {
    // ask for input monitoring first
    mousedownEventTapRef = [helperLib listenMouseDown];
    mouseupEventTapRef = [helperLib listenMouseUp];
    mousemoveEventTapRef = [helperLib listenMouseMove];
}
+ (void) stopListening {
    CFRelease(mousedownEventTapRef);
    mousedownEventTapRef = NULL;
    CFRelease(mouseupEventTapRef);
    mouseupEventTapRef = NULL;
}
@end
