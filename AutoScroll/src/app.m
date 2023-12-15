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
+ (void) mousedown: (CGEventRef) e : (CGEventType) type {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) if (!CGEventTapIsEnabled(mousedownEventTapRef)) CGEventTapEnable(mousedownEventTapRef, true);

}
+ (void) mouseup: (CGEventRef) e : (CGEventType) type {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) if (!CGEventTapIsEnabled(mouseupEventTapRef)) CGEventTapEnable(mouseupEventTapRef, true);

}
+ (void) mousemove: (CGEventRef) e : (CGEventType) type {
    if (type == kCGEventTapDisabledByTimeout || type == kCGEventTapDisabledByUserInput) if (!CGEventTapIsEnabled(mousemoveEventTapRef)) CGEventTapEnable(mousemoveEventTapRef, true);

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
