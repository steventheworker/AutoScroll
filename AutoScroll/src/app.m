//
//  app.m
//  AutoScroll
//
//  Created by Steven G on 8/20/23.
//

#import "app.h"
#import "autoscroll.h"
#import "helperLib.h"

@implementation app
+ (void) mousedown: (CGEventRef) e : (CGEventType) etype {
    NSLog(@"md");
}
+ (void) mouseup: (CGEventRef) e : (CGEventType) etype {
    NSLog(@"mu");
}
+ (void) init {
    [autoscroll init];
    [helperLib listenMouseUp];
    [helperLib listenMouseDown];
}
@end
