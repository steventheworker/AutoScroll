//
//  autoscroll.m
//  screenhook
//
//  Created by Steven G on 8/18/23.
//

#import "autoscroll.h"
#import "helperLib.h"
#import "globals.h"

//"config"
int autoscrollIconSize = 32;
NSArray* blacklist = @[];
BOOL isBlacklisted(NSString* appBID) {
    for (NSString *str in blacklist)
        if ([str isEqualToString: appBID]) return YES;
    return NO;
}
NSArray* parseBlacklistStr(NSString* str) {
    NSMutableArray* ret = NSMutableArray.array;
    for (NSString* line in [str componentsSeparatedByString: @"\n"]) {
        NSString* appbid = [line stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (appbid.length) [ret addObject: appbid];
    }
    return ret;
}

NSWindow* autoscrollImageWindow;
NSTimer* timerRef;
CGPoint startPoint; // start cursor position
CGPoint cur; // current cursor position
int scrollCounter = -1; //every time interval runs +1, resets on mouseup (-1 === disabled)
void (^autoscrollLoop)(NSTimer *timer) = ^(NSTimer *timer) {
    if (scrollCounter == -1) return;
    int dx = cur.x - startPoint.x;
    int dy = cur.y - startPoint.y;
    scrollCounter++;

    // Move the mouse to the startPoint coordinates
    CGPoint movePoint = CGPointMake(startPoint.x, startPoint.y);
    CGEventRef moveEvent = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, movePoint, kCGMouseButtonCenter);
    CGEventPost(kCGHIDEventTap, moveEvent);
    CFRelease(moveEvent);

    usleep(10000);  // 10ms, Wait a bit to let the mouse movement take effect

    // Create and post a scroll event at the new mouse position
    CGEventRef scrollEvent = CGEventCreateScrollWheelEvent(NULL,
                                                           kCGScrollEventUnitLine,
                                                           2, // number of wheel units (positive for forward, negative for backward)
                                                           dy / 8, // number of vertical wheel units
                                                           dx / 16, // number of horizontal wheel units,
                                                           0); // no modifier flags
    CGEventPost(kCGHIDEventTap, scrollEvent);
    CFRelease(scrollEvent);
    
    // Move the mouse to the cur coordinates
    CGPoint movePoint2 = CGPointMake(cur.x, cur.y);
    CGEventRef moveEvent2 = CGEventCreateMouseEvent(NULL, kCGEventMouseMoved, movePoint2, kCGMouseButtonCenter);
    CGEventPost(kCGHIDEventTap, moveEvent2);
    CFRelease(moveEvent2);
};



void shouldTriggerMiddleClick(void) { // allows middle clicks to go through if intention wasn't to scroll
    int dx = cur.x - startPoint.x;
    int dy = cur.y - startPoint.y;
    if (abs(dx) + abs(dy) > 4) return; // probably intended to scroll
    if (scrollCounter > 5 && abs(dx) + abs(dy) > 2) return; // probably intended to scroll
    // Simulate a middle click
    [helperLib setSimulatedClickFlag: YES];
    CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseDown,cur,kCGMouseButtonCenter));
    CGEventPost (kCGHIDEventTap, CGEventCreateMouseEvent (NULL,kCGEventOtherMouseUp,cur,kCGMouseButtonCenter));
}
id windowWithEl(id el) {
    if (!el || (id)@0 == el) return nil;
    if ([[helperLib elementDict: el : @{@"role": (id)kAXRoleAttribute}][@"role"] isEqual: @"AXWindow"]) return el;
    return windowWithEl([helperLib elementDict: el : @{@"parent": (id)kAXParentAttribute}][@"parent"]);
}
id rootElHavingRole(id el, NSString* roleMatch) {
    for (id child in [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"])
        if ([[helperLib elementDict: child : @{@"role": (id)kAXRoleAttribute}][@"role"] isEqual: roleMatch])
            return child;
    return nil;
}
BOOL isElInSidebar(id win, id el, CGPoint mouseLoc) {
    id sidebarContainer = [helperLib elementDict: win : @{@"children": (id)kAXChildrenAttribute}][@"children"][0]; // first window UI Element = AXUknown (group) (which is the container)
    id sidebar = rootElHavingRole(sidebarContainer, @"AXScrollArea");
    NSDictionary* dict = [helperLib elementDict: sidebar : @{
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute
    }];
    if (mouseLoc.x >= [dict[@"pos"][@"x"] floatValue] && mouseLoc.x <= [dict[@"pos"][@"x"] floatValue] + [dict[@"size"][@"width"] floatValue])
    if (mouseLoc.y >= [dict[@"pos"][@"y"] floatValue] && mouseLoc.y <= [dict[@"pos"][@"y"] floatValue] + [dict[@"size"][@"height"] floatValue])
        return YES;
    return NO;
}
BOOL isPIPMainWindow(id win) {
    id appEl = [helperLib elementDict: win : @{@"p": (id)kAXParentAttribute}][@"p"];
    id appMainWindow = [helperLib elementDict: appEl : @{@"main": (id)kAXMainWindowAttribute}][@"main"];
    if ([[helperLib elementDict: appMainWindow : @{@"title": (id)kAXTitleAttribute}][@"title"] isEqual: @"Picture-in-Picture"]) return YES;
    return NO;
}
BOOL isElInDevTools(id el, int currentDepth) { // initial call w/ currentDepth=0
    if (!el) return NO;
    el = [helperLib elementDict: el : @{@"p": (id)kAXParentAttribute}][@"p"];
    NSDictionary* dict = [helperLib elementDict: el : @{@"title": (id)kAXTitleAttribute}];
    if ([dict[@"title"] isEqual: @"Developer Tools"]) return YES;
    return ++currentDepth >= 30 /* max depth */ ? NO : isElInDevTools(el, currentDepth);
}
BOOL appHasPartialImplementation(NSRunningApplication* app, CGEventRef e) { //eg: firefox lets you autoscroll, but not on the sidebar, so we propagate all but the sidebar
    if ([app.localizedName hasPrefix: @"Firefox"]) {
        CGPoint mouseLoc = CGEventGetLocation(e);
        id el = [helperLib elementAtPoint: mouseLoc];
        NSDictionary* dict = [helperLib elementDict: el : @{@"pid": (id)kAXPIDAttribute}];
        pid_t mousepid = [dict[@"pid"] intValue];
        if (mousepid != app.processIdentifier) return NO; //middle clicking outside of Firefox
        id win = windowWithEl(el);
        if (isElInSidebar(win, el, mouseLoc) || isPIPMainWindow(win) || isElInDevTools(el, 0)) return NO; // use AutoScroll.app
        return YES; // propagate (so the app uses its own implementation)
    }
    return NO;
}

void overrideDefaultMiddleMouseDown(CGEventRef e) {
    if (!autoscrollImageWindow) return;
    cur = CGEventGetLocation(e);
    NSUInteger _flags = [NSEvent modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask;
    NSMutableDictionary<NSString *, NSNumber *> *modifierStates = [NSMutableDictionary dictionary];
    if ((_flags & NSEventModifierFlagControl) != 0) modifierStates[@"ctrl"] = @1;
    if ((_flags & NSEventModifierFlagOption) != 0) modifierStates[@"opt"] = @1;
    if ((_flags & NSEventModifierFlagCommand) != 0)modifierStates[@"cmd"] = @1;
    if ((_flags & NSEventModifierFlagShift) != 0) modifierStates[@"shift"] = @1;
    NSDictionary<NSString *, NSNumber *> *immutableDictionary = [modifierStates copy];

    int waitT = 0;
    if (immutableDictionary.count >= 3) waitT = 333;

    setTimeout(^{
        scrollCounter = 0;
        startPoint = cur;
        if (timerRef) [timerRef invalidate];
        timerRef = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:autoscrollLoop];
        //custom cursor
        [autoscrollImageWindow setIsVisible:YES];
        float convertedY = [[helperLib getMouseScreen] frame].size.height - cur.y;
        [autoscrollImageWindow setFrame: NSMakeRect(cur.x - autoscrollIconSize/2, convertedY - autoscrollIconSize/2, autoscrollIconSize, autoscrollIconSize) display: YES];
    }, waitT);
}
void overrideDefaultMiddleMouseUp(CGEventRef e) {
    if (!autoscrollImageWindow) return;
    shouldTriggerMiddleClick();
    cur = CGEventGetLocation(e);
    scrollCounter = -1; // disable autoscroll
    if (timerRef) [timerRef invalidate];
    // Restore the cursor to its default state
    [autoscrollImageWindow setIsVisible:NO];
}

@implementation autoscroll
+ (void) init {
    //create window from xib
    autoscrollImageWindow = [[[NSWindowController alloc] initWithWindowNibName:@"autoscroll-overlay"] window];
    [autoscrollImageWindow setLevel: NSPopUpMenuWindowLevel]; //float window
    [autoscrollImageWindow setIgnoresMouseEvents:YES]; //allows the scroll to not be absorbed by the window
    [autoscrollImageWindow setBackgroundColor:[NSColor clearColor]]; //transparent window background
    setTimeout(^{[self updateBlacklist];}, 0);
}
+ (void) updateBlacklist {
    NSString* txt = ((NSTextView*)[helperLib getApp]->blacklistView.documentView).string;
    blacklist = parseBlacklistStr(txt);
}
+ (BOOL) mousedown: (CGEventRef) e : (CGEventType) etype {
    if (etype != kCGEventOtherMouseDown) return YES;
    NSRunningApplication* activeApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (isBlacklisted(activeApp.bundleIdentifier) || appHasPartialImplementation(activeApp, e)) return YES;
    overrideDefaultMiddleMouseDown(e);
    return NO;
}
+ (BOOL) mouseup: (CGEventRef) e : (CGEventType) etype {
    if (etype != kCGEventOtherMouseUp) return YES;
    NSRunningApplication* activeApp = [[NSWorkspace sharedWorkspace] frontmostApplication];
    if (isBlacklisted(activeApp.bundleIdentifier) || (scrollCounter == -1 && appHasPartialImplementation(activeApp, e))) return YES;
    overrideDefaultMiddleMouseUp(e);
    return NO;
}
+ (void) mousemove: (CGEventRef) e : (CGEventType) etype {
    if (scrollCounter == -1) return;
    cur = CGEventGetLocation(e);
}
@end
