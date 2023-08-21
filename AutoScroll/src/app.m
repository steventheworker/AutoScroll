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

@implementation app
+ (void) mousedown: (CGEventRef) e : (CGEventType) etype {
    
}
+ (void) mouseup: (CGEventRef) e : (CGEventType) etype {
    
}
+ (void) mousemove: (CGEventRef) e : (CGEventType) etype {
    
}
+ (void) init {
    [autoscroll init];
    [helperLib listenMouseUp];
    [helperLib listenMouseDown];
    [helperLib listenMouseMove];
}
@end
