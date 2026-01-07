//
//  helperLib.m
//  screenhook
//
//  Created by Steven G on x/x/22.
//

#import "helperLib.h"
#import "globals.h"
#import "autoscroll.h"

AXUIElementRef systemWideElement;

BOOL isMiddleClickSimulated = NO;

NSDictionary* appAliases = @{
    @"Visual Studio Code": @"Code",
    @"Adobe Lightroom Classic": @"Lightroom Classic",
    @"iTerm": @"iTerm2",
    @"PyCharm CE": @"PyCharm"
};

////prepare click handling
CGEventTapCallBack handleMouseDown(CGEventTapProxy proxy ,
                                  CGEventType type ,
                                  CGEventRef event ,
                                  void * refcon ) {
    if (isMiddleClickSimulated) return (CGEventTapCallBack) event; //  don't listen to simulated clicks, guarantees simulated click fires
    [[helperLib getApp] mousedown: event : type];
    return [autoscroll mousedown: event : type] ? (CGEventTapCallBack) event : nil;
}
CGEventTapCallBack handleMouseUp(CGEventTapProxy proxy ,
                                  CGEventType type ,
                                  CGEventRef event ,
                                  void * refcon ) {
    if (isMiddleClickSimulated) {isMiddleClickSimulated = NO;return (CGEventTapCallBack) event;} //  don't listen to simulated clicks, guarantees simulated click fires
    [[helperLib getApp] mouseup: event : type];
    return [autoscroll mouseup: event : type] ? (CGEventTapCallBack) event : nil;
}
CGEventTapCallBack handleMouseMove(CGEventTapProxy proxy ,
                                  CGEventType type ,
                                  CGEventRef event ,
                                  void * refcon ) {
    [[helperLib getApp] mousemove: event : type];
    [autoscroll mousemove: event : type];
    return (CGEventTapCallBack) event;
}
//listening to monitors attach / detach
void proc(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void* userInfo) {
    if (flags && kCGDisplayAddFlag && kCGDisplayRemoveFlag) {} else return;
    [[helperLib getApp] bindScreens];
}

@implementation helperLib
//formatting
+ (NSString*) twoSigFigs: (float) val {
    return [NSString stringWithFormat:@"%.02f", val];
}
//misc
+ (void) setSimulatedClickFlag: (BOOL) val {isMiddleClickSimulated = val;}
+ (void) nextSpace {[[[NSAppleScript alloc] initWithSource: @"tell application \"System Events\" to key code 124 using {control down}"] executeAndReturnError: nil];}
+ (void) previousSpace {[[[NSAppleScript alloc] initWithSource: @"tell application \"System Events\" to key code 123 using {control down}"] executeAndReturnError: nil];}
+ (NSString*) runScript: (NSString*) scriptTxt {
    NSDictionary *error = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource: scriptTxt];
    if (error) {
        NSLog(@"run error: %@", error);
        return @"";
    }
    return [[script executeAndReturnError:&error] stringValue];
}
+ (void) runAppleScriptAsync: (NSString*) scriptTxt : (void(^)(NSString*)) cb {
    NSTask *task = [[NSTask alloc] init];
    scriptTxt = [NSString stringWithFormat: @"'%@'", [scriptTxt stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]; // escape '
    [task setLaunchPath: @"/bin/bash"];
    scriptTxt = [NSString stringWithFormat: @"/usr/bin/osascript -e %@", scriptTxt];
    [task setArguments: [NSArray arrayWithObjects:@"-c", scriptTxt, nil]];
    NSPipe *standardOutput = [[NSPipe alloc] init];
    [task setStandardOutput:standardOutput];
    [[NSNotificationCenter defaultCenter] addObserverForName: NSFileHandleReadCompletionNotification object: [standardOutput fileHandleForReading] queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
        NSData *data = [[notification userInfo] objectForKey: NSFileHandleNotificationDataItem];
        NSFileHandle *handle = [notification object];
        if ([data length]) {
            NSString* str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            cb([str substringToIndex:[str length]-1]); // remove end of line \n
        } else {
            [[NSNotificationCenter defaultCenter] removeObserver: self name: NSFileHandleReadCompletionNotification object: [notification object]];
            cb(nil);
        }
    }];
    [task launch];
    [[standardOutput fileHandleForReading] readInBackgroundAndNotify];
}
+ (void) runAppleScript: (NSString*) scptPath {
    NSString *compiledScriptPath = [[NSBundle mainBundle] pathForResource:scptPath ofType:@"scpt" inDirectory:@"Scripts"];
    NSDictionary *error = nil;
    NSAppleScript *script = [[NSAppleScript alloc] initWithContentsOfURL:[NSURL fileURLWithPath:compiledScriptPath] error:&error];
    if (error) {
        NSLog(@"compile error: %@", error);
    } else {
       [script executeAndReturnError:&error];
       if (error) {
         NSLog(@"run error: %@", error);
       }
    }
}

// point math / screens
+ (CGPoint) carbonPointFrom:(NSPoint) cocoaPoint {
    NSScreen* screen = [helperLib getScreen:0];
    float menuScreenHeight = NSMaxY([screen frame]);
    return CGPointMake(cocoaPoint.x,  menuScreenHeight - cocoaPoint.y);
}
+ (void) triggerKeycode:(CGKeyCode) key {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventRef down = CGEventCreateKeyboardEvent(src, key, true);
    CGEventRef up = CGEventCreateKeyboardEvent(src, key, false);
    CGEventPost(kCGHIDEventTap, down);
    CGEventPost(kCGHIDEventTap, up);
    CFRelease(down);
    CFRelease(up);
    CFRelease(src);
}
+ (NSScreen*) getMouseScreen {
    return [self getScreen:0];
}
+ (NSScreen*) getScreen: (int) screenIndex {
    NSScreen* screen = nil;
    int i = 0;
    //check if monitor exist
    for (NSScreen *candidate in [NSScreen screens]) { //loop through screens
        if (i == 0 && !NSPointInRect(NSZeroPoint, [candidate frame])) continue; //the first screen is always zeroed out, other screens have offsets
        screen = candidate;
        if (i++ == screenIndex) break;
    }
    //if    &&  screenIndex  &&  loop return's primary monitor (the only monitor)     =>    screen = nil
    if (screen && screenIndex && ![screen frame].origin.x && ![screen frame].origin.y) screen = nil;
    return screen;
}

//app stuff
+ (AppDelegate *) getApp {return ((AppDelegate *)[[helperLib sharedApplication] delegate]);}
+ (NSApplication*) sharedApplication {return [NSApplication sharedApplication];}
+ (pid_t) getPID: (NSString*) tar {
    NSArray *appList = [[NSWorkspace sharedWorkspace] runningApplications];
    for (int i = 0; i < appList.count; i++) {
        NSRunningApplication *cur = appList[i];
        if (![tar isEqualTo: cur.bundleIdentifier]) continue;
        return cur.processIdentifier;
    }
    return 0;
}
+ (NSRunningApplication*) runningAppFromAxTitle:(NSString*) tar {
    NSArray *appList = [[NSWorkspace sharedWorkspace] runningApplications];
    for (int i = 0; i < appList.count; i++) {
        NSRunningApplication *cur = appList[i];
        if (![tar isEqualTo: cur.localizedName]) continue;
        return cur;
    }
    return nil;
}

//windows
+ (NSMutableArray*) getWindowsForOwnerOnScreen: (NSString *)owner {
    if (!owner || [@"" isEqual:owner]) return nil;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSMutableArray *ownerWindowList = [NSMutableArray new];
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if (![owner isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]]) continue;
        [ownerWindowList addObject:win];
    }
    CFRelease(windowList);
    return ownerWindowList;
}
+ (NSMutableArray*) getWindowsForOwner: (NSString *)owner {
    if (!owner || [@"" isEqual:owner]) return nil;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    NSMutableArray *ownerWindowList = [NSMutableArray new];
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if (![owner isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]]) continue;
        [ownerWindowList addObject:win];
    }
    CFRelease(windowList);
    return ownerWindowList;
}
+ (NSMutableArray*) getWindowsForOwnerPID:(pid_t) PID {
  if (!PID) return nil;
  CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);
  NSMutableArray *ownerWindowList = [NSMutableArray new];
  long int windowCount = CFArrayGetCount(windowList);
  for (int i = 0; i < windowCount; i++) {
      NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
      NSNumber* curPID = [win objectForKey:@"kCGWindowOwnerPID"];
      if (PID != (pid_t) [curPID intValue]) continue;
      [ownerWindowList addObject:win];
  }
  CFRelease(windowList);
  return ownerWindowList;
}
+ (NSMutableArray*) getRealFinderWindows {
    AppDelegate* del = [helperLib getApp];
    NSMutableArray* finderWins = [helperLib getWindowsForOwner:@"Finder"];
    NSMutableArray *ownerWindowList = [NSMutableArray new];
    for (NSDictionary* win in finderWins) {
        int winLayer = [[win objectForKey:@"kCGWindowLayer"] intValue];
        NSDictionary* bounds = [win objectForKey:@"kCGWindowBounds"];
        float w = [[bounds objectForKey:@"Width"] floatValue];
        float h = [[bounds objectForKey:@"Height"] floatValue];
//        float x = [[bounds objectForKey:@"X"] floatValue];
        float y = [[bounds objectForKey:@"Y"] floatValue];
//        if (winLayer < 0) continue; //winLayer is negative when it's the desktop's "finder" window
//        if (winLayer == 3) continue; //i think this is the desktop's finder window... (no other way to tell but size.x & size.y)
        if (winLayer != 0) continue; //not a standard window
        if (w < 100 || h < 100) continue; //no menu bar windows or teeny tiny windows (not possible anyways i think)
        if (y+h == del->primaryScreenHeight - (del->dockHeight ? del->dockHeight : 80) - 20 - 21) continue; //20 == MENUBARHEIGHT and 21 is where the ghost window shows for me... //todo: seeing if it vary's (the 21)
        [ownerWindowList addObject:win];
    }
    return ownerWindowList;
}
+ (int) numWindowsMinimized: (NSString*) tar {
    int numWindows = 0; //# minimized windows on active space
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll|kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        //get dictionary data
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if (![tar isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]] || [[win objectForKey:@"kCGWindowLayer"] intValue] != 0) continue;
        // Get the AXUIElement windowList (e.g. elementList)
        int winPID = [[win objectForKey:@"kCGWindowOwnerPID"] intValue];
        AXUIElementRef appRef = AXUIElementCreateApplication(winPID);
        CFArrayRef elementList;
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, (void *)&elementList);
        CFRelease(appRef);
        bool onActiveSpace = YES;
        //loop through looking for minimized && onActiveSpace
        long int numElements = elementList ? CFArrayGetCount(elementList) : 0;
        for (int j = 0; j < numElements; j++) {
            AXUIElementRef winElement = CFArrayGetValueAtIndex(elementList, j);
            CFBooleanRef winMinimized;
            AXUIElementCopyAttributeValue(winElement, kAXMinimizedAttribute, (CFTypeRef *)&winMinimized);
            if (winMinimized == kCFBooleanTrue && onActiveSpace) numWindows++;
//            CFRelease(winMinimized);
        }
//        CFRelease(elementList); //causes crashes
    }
    CFRelease(windowList);
    return numWindows;
}


//AXUI elements
+ (void) setSystemWideEl: (AXUIElementRef) el { //used in elementAtPoint, etc. (Practically an init function)
    systemWideElement = el;
}
+ (id) elementAtPoint: (CGPoint) pt {
    AXUIElementRef element = NULL;
    AXError result = AXUIElementCopyElementAtPosition(systemWideElement, pt.x, pt.y, &element);
    if (result != kAXErrorSuccess) NSLog(@"%f, %f elementAtPoint failed", pt.x, pt.y);
    return (__bridge_transfer id)element; // ARC takes ownership, otherwise need to call CFRelease somewhere down the line
}
+ (NSDictionary*) elementDict: (id) elID : (NSDictionary*) attributeDict {
    AXUIElementRef el = (__bridge AXUIElementRef)(elID);
    if (!el) return @{};
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (NSString* attributeName in attributeDict) {
        id attribute = attributeDict[attributeName];
        /* kAXAllowedValuesAttribute kAXAMPMFieldAttribute kAXCancelButtonAttribute kAXChildrenAttribute kAXCloseButtonAttribute
         kAXColumnHeaderUIElementsAttribute kAXColumnsAttribute kAXColumnTitleAttribute kAXContentsAttribute kAXDayFieldAttribute
         kAXDecrementButtonAttribute kAXDefaultButtonAttribute kAXDescriptionAttribute kAXDisclosedByRowAttribute kAXDisclosedRowsAttribute
         kAXDisclosingAttribute kAXDocumentAttribute kAXEditedAttribute kAXEnabledAttribute kAXExpandedAttribute
         kAXFilenameAttribute kAXFocusedApplicationAttribute kAXFocusedAttribute kAXFocusedUIElemenAttribute kAXFocusedWindowAttribute
         kAXFrontmostAttribute kAXGrowAreaAttribute kAXHeaderAttribute kAXHelpAttribute kAXHourFieldAttribute
         kAXIncrementorAttribute kAXInsertionPointLineNumberAttribute kAXMainAttribute kAXMaxValueAttribute kAXMinimizeButtonAttribute
         kAXMinimizedAttribute kAXMinuteFieldAttribute kAXMinValueAttribute kAXModalAttribute kAXMonthFieldAttribute
         kAXNumberOfCharactersAttribute kAXOrientationAttribute kAXParentAttribute kAXPositionAttribute kAXProxyAttribute
         kAXRoleAttribute kAXRoleDescriptionAttribute kAXSecondFieldAttribute kAXSelectedChildrenAttribute kAXSelectedTextAttribute
         kAXSelectedTextRangeAttribute kAXSelectedTextRangesAttribute kAXSharedCharacterRangeAttribute kAXSharedTextUIElementsAttribute kAXSizeAttribute
         kAXSubroleAttribute kAXTitleAttribute kAXToolbarButtonAttribute kAXTopLevelUIElementAttribute kAXURLAttribute
         kAXValueAttribute kAXValueDescriptionAttribute kAXValueIncrementAttribute kAXVisibleCharacterRangeAttribute kAXVisibleChildrenAttribute
         kAXVisibleColumnsAttribute kAXWindowAttribute kAXYearFieldAttribute kAXZoomButtonAttribute */
        if (attribute == (id)kAXAllowedValuesAttribute) {
            // Handle kAXAllowedValuesAttribute
        } else if (attribute == (id)kAXAMPMFieldAttribute) {
            // Handle kAXAMPMFieldAttribute
        } else if (attribute == (id)kAXCancelButtonAttribute) {
            // Handle kAXCancelButtonAttribute
        } else if (attribute == (id)kAXChildrenAttribute) {
            NSArray* children;
            AXError result = AXUIElementCopyAttributeValue(el, kAXChildrenAttribute, (void*)&children);
            if (result == kAXErrorSuccess) dict[attributeName] = children;
            else dict[attributeName] = @[];
        } else if (attribute == (id)kAXCloseButtonAttribute) {
            // Handle kAXCloseButtonAttribute
        } else if (attribute == (id)kAXColumnsAttribute) {
            // Handle kAXColumnsAttribute
        } else if (attribute == (id)kAXColumnHeaderUIElementsAttribute) {
            // Handle kAXColumnHeaderUIElementsAttribute
        } else if (attribute == (id)kAXColumnTitleAttribute) {
            // Handle kAXColumnTitleAttribute
        } else if (attribute == (id)kAXContentsAttribute) {
            // Handle kAXContentsAttribute
        } else if (attribute == (id)kAXDayFieldAttribute) {
            // Handle kAXDayFieldAttribute
        } else if (attribute == (id)kAXDecrementButtonAttribute) {
            // Handle kAXDecrementButtonAttribute
        } else if (attribute == (id)kAXDefaultButtonAttribute) {
            // Handle kAXDefaultButtonAttribute
        } else if (attribute == (id)kAXDescriptionAttribute) {
            // Handle kAXDescriptionAttribute
        } else if (attribute == (id)kAXDisclosedByRowAttribute) {
            // Handle kAXDisclosedByRowAttribute
        } else if (attribute == (id)kAXDisclosedRowsAttribute) {
            // Handle kAXDisclosedRowsAttribute
        } else if (attribute == (id)kAXDisclosingAttribute) {
            // Handle kAXDisclosingAttribute
        } else if (attribute == (id)kAXDocumentAttribute) {
            // Handle kAXDocumentAttribute
        } else if (attribute == (id)kAXEditedAttribute) {
            // Handle kAXEditedAttribute
        } else if (attribute == (id)kAXEnabledAttribute) {
            // Handle kAXEnabledAttribute
        } else if (attribute == (id)kAXExpandedAttribute) {
            // Handle kAXExpandedAttribute
        } else if (attribute == (id)kAXFilenameAttribute) {
            // Handle kAXFilenameAttribute
        } else if (attribute == (id)kAXFocusedApplicationAttribute) {
            AXUIElementRef app;
            AXError result = AXUIElementCopyAttributeValue(el, kAXFocusedApplicationAttribute, (void*)&app);
            if (result == kAXErrorSuccess) dict[attributeName] = (__bridge id)app;
            else dict[attributeName] = @0;
        } else if (attribute == (id)kAXFocusedAttribute) {
            // Handle kAXFocusedAttribute
        } else if (attribute == (id)kAXFocusedUIElementAttribute) {
            // Handle kAXFocusedUIElementAttribute
        } else if (attribute == (id)kAXFocusedWindowAttribute) {
            AXUIElementRef axWindow;
            AXError result = AXUIElementCopyAttributeValue(el, kAXFocusedWindowAttribute, (void*)&axWindow);
            if (result == kAXErrorSuccess) dict[attributeName] = (__bridge id)axWindow;
            else dict[attributeName] = @0;
        } else if (attribute == (id)kAXFrontmostAttribute) {
            // Handle kAXFrontmostAttribute
        } else if (attribute == (id)kAXGrowAreaAttribute) {
            // Handle kAXGrowAreaAttribute
        } else if (attribute == (id)kAXHeaderAttribute) {
            // Handle kAXHeaderAttribute
        } else if (attribute == (id)kAXHelpAttribute) {
            // Handle kAXHelpAttribute
        } else if (attribute == (id)kAXHiddenAttribute) {
            // Handle kAXHiddenAttribute
        } else if (attribute == (id)kAXHorizontalScrollBarAttribute) {
            // Handle kAXHorizontalScrollBarAttribute
        } else if (attribute == (id)kAXHourFieldAttribute) {
            // Handle kAXHourFieldAttribute
        } else if (attribute == (id)kAXIdentifierAttribute) {
            CFTypeRef idVal;
            AXError result = AXUIElementCopyAttributeValue(el, kAXIdentifierAttribute, &idVal);
            if (result == kAXErrorSuccess && CFGetTypeID(idVal) == CFStringGetTypeID()) {
                dict[attributeName] = (__bridge NSString*) idVal;
                CFRelease(idVal);
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXIncrementorAttribute) {
            // Handle kAXIncrementorAttribute
        } else if (attribute == (id)kAXIndexAttribute) {
            // Handle kAXIndexAttribute
        } else if (attribute == (id)kAXInsertionPointLineNumberAttribute) {
            // Handle kAXInsertionPointLineNumberAttribute
        } else if (attribute == (id)kAXIsApplicationRunningAttribute) {
            NSNumber* isApplicationRunning;
            AXError result = AXUIElementCopyAttributeValue(el, kAXIsApplicationRunningAttribute, (void*)&isApplicationRunning);
            if (result == kAXErrorSuccess) dict[attributeName] = @([isApplicationRunning intValue]);
            else dict[attributeName] = @NO;
        } else if (attribute == (id)kAXLabelUIElementsAttribute) {
            // Handle kAXLabelUIElementsAttribute
        } else if (attribute == (id)kAXLabelValueAttribute) {
            // Handle kAXLabelValueAttribute
        } else if (attribute == (id)kAXLinkedUIElementsAttribute) {
            // Handle kAXLinkedUIElementsAttribute
        } else if (attribute == (id)kAXMainAttribute) {
            // Handle kAXMainAttribute
        } else if (attribute == (id)kAXMatteContentUIElementAttribute) {
            // Handle kAXMatteContentUIElementAttribute
        } else if (attribute == (id)kAXMatteHoleAttribute) {
            // Handle kAXMatteHoleAttribute
        } else if (attribute == (id)kAXMainWindowAttribute) {
            AXUIElementRef axWindow;
            AXError result = AXUIElementCopyAttributeValue(el, kAXMainWindowAttribute, (void*)&axWindow);
            if (result == kAXErrorSuccess) dict[attributeName] = (__bridge id)axWindow;
            else dict[attributeName] = @0;
        } else if (attribute == (id)kAXMaxValueAttribute) {
            // Handle kAXMaxValueAttribute
        } else if (attribute == (id)kAXMenuBarAttribute) {
            AXUIElementRef menuBar;
            AXError result = AXUIElementCopyAttributeValue(el, kAXMenuBarAttribute, (void*)&menuBar);
            if (result == kAXErrorSuccess) dict[attributeName] = (__bridge id)menuBar;
            else dict[attributeName] = @0;
        } else if (attribute == (id)kAXMenuItemCmdCharAttribute) {
            // Handle kAXMenuItemCmdCharAttribute
        } else if (attribute == (id)kAXMenuItemCmdGlyphAttribute) {
            // Handle kAXMenuItemCmdGlyphAttribute
        } else if (attribute == (id)kAXMenuItemCmdModifiersAttribute) {
            // Handle kAXMenuItemCmdModifiersAttribute
        } else if (attribute == (id)kAXMenuItemCmdVirtualKeyAttribute) {
            // Handle kAXMenuItemCmdVirtualKeyAttribute
        } else if (attribute == (id)kAXMenuItemMarkCharAttribute) {
            // Handle kAXMenuItemMarkCharAttribute
        } else if (attribute == (id)kAXMenuItemPrimaryUIElementAttribute) {
            // Handle kAXMenuItemPrimaryUIElementAttribute
        } else if (attribute == (id)kAXMinimizeButtonAttribute) {
            // Handle kAXMinimizeButtonAttribute
        } else if (attribute == (id)kAXMinimizedAttribute) {
            BOOL val;
            AXError result = AXUIElementCopyAttributeValue(el, kAXMinimizedAttribute, (void*)&val);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = @(val);
            } else dict[attributeName] = @NO;
        } else if (attribute == (id)kAXMinuteFieldAttribute) {
            // Handle kAXMinuteFieldAttribute
        } else if (attribute == (id)kAXMinValueAttribute) {
            // Handle kAXMinValueAttribute
        } else if (attribute == (id)kAXModalAttribute) {
            // Handle kAXModalAttribute
        } else if (attribute == (id)kAXMonthFieldAttribute) {
            // Handle kAXMonthFieldAttribute
        } else if (attribute == (id)kAXNextContentsAttribute) {
            // Handle kAXNextContentsAttribute
        } else if (attribute == (id)kAXNumberOfCharactersAttribute) {
            // Handle kAXNumberOfCharactersAttribute
        } else if (attribute == (id)kAXOrientationAttribute) {
            // Handle kAXOrientationAttribute
        } else if (attribute == (id)kAXOverflowButtonAttribute) {
            // Handle kAXOverflowButtonAttribute
        } else if (attribute == (id)kAXParentAttribute) {
            AXUIElementRef parent;
            AXError result = AXUIElementCopyAttributeValue(el, kAXParentAttribute, (void*)&parent);
            if (result == kAXErrorSuccess) dict[attributeName] = (__bridge_transfer id)parent;
            else dict[attributeName] = @0;
        } else if (attribute == (id)kAXPositionAttribute) {
            CFTypeRef positionRef;
            AXError result = AXUIElementCopyAttributeValue(el, kAXPositionAttribute, (void*)&positionRef);
            if (result == kAXErrorSuccess) {
                CGPoint curPt;
                AXValueGetValue(positionRef, kAXValueCGPointType, &curPt);
                dict[attributeName] = @{@"x": @(curPt.x), @"y": @(curPt.y)};
                CFRelease(positionRef);
            } else dict[attributeName] = @{@"": @0, @"y": @0};
        } else if (attribute == (id)kAXPreviousContentsAttribute) {
            // Handle kAXPreviousContentsAttribute
        } else if (attribute == (id)kAXProxyAttribute) {
            // Handle kAXProxyAttribute
        } else if (attribute == (id)kAXRoleAttribute) {
            CFTypeRef subroleValue;
            AXError result = AXUIElementCopyAttributeValue(el, kAXRoleAttribute, &subroleValue);
            if (result == kAXErrorSuccess && CFGetTypeID(subroleValue) == CFStringGetTypeID()) {
                NSString* subrole = (__bridge NSString*) subroleValue;
                dict[attributeName] = subrole;
                CFRelease(subroleValue);
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXRoleDescriptionAttribute) {
            // Handle kAXRoleDescriptionAttribute
        } else if (attribute == (id)kAXRowsAttribute) {
            // Handle kAXRowsAttribute
        } else if (attribute == (id)kAXSecondFieldAttribute) {
            // Handle kAXSecondFieldAttribute
        } else if (attribute == (id)kAXSelectedAttribute) {
            // Handle kAXSelectedAttribute
        } else if (attribute == (id)kAXSelectedChildrenAttribute) {
            // Handle kAXSelectedChildrenAttribute
        } else if (attribute == (id)kAXSelectedColumnsAttribute) {
            // Handle kAXSelectedColumnsAttribute
        } else if (attribute == (id)kAXSelectedRowsAttribute) {
            // Handle kAXSelectedRowsAttribute
        } else if (attribute == (id)kAXSelectedTextAttribute) {
            // Handle kAXSelectedTextAttribute
        } else if (attribute == (id)kAXSelectedTextRangeAttribute) {
            // Handle kAXSelectedTextRangeAttribute
        } else if (attribute == (id)kAXSelectedTextRangesAttribute) {
            // Handle kAXSelectedTextRangesAttribute
        } else if (attribute == (id)kAXServesAsTitleForUIElementsAttribute) {
            // Handle kAXServesAsTitleForUIElementsAttribute
        } else if (attribute == (id)kAXSharedCharacterRangeAttribute) {
            // Handle kAXSharedCharacterRangeAttribute
        } else if (attribute == (id)kAXSharedTextUIElementsAttribute) {
            // Handle kAXSharedTextUIElementsAttribute
        } else if (attribute == (id)kAXShownMenuUIElementAttribute) {
            // Handle kAXShownMenuUIElementAttribute
        } else if (attribute == (id)kAXSizeAttribute) {
            CFTypeRef sizeRef;
            AXError result = AXUIElementCopyAttributeValue(el, kAXSizeAttribute, (void*)&sizeRef);
            if (result == kAXErrorSuccess) {
                CGSize curSize;
                AXValueGetValue(sizeRef, kAXValueCGSizeType, &curSize);
                dict[attributeName] = @{@"width": @(curSize.width), @"height": @(curSize.height)};
                CFRelease(sizeRef);
            } else dict[attributeName] = @{@"width": @0, @"height": @0};
        } else if (attribute == (id)kAXSortDirectionAttribute) {
            // Handle kAXSortDirectionAttribute
        } else if (attribute == (id)kAXSplittersAttribute) {
            // Handle kAXSplittersAttribute
        } else if (attribute == (id)kAXSubroleAttribute) {
            CFTypeRef subroleValue;
            AXError result = AXUIElementCopyAttributeValue(el, kAXSubroleAttribute, &subroleValue);
            if (result == kAXErrorSuccess && CFGetTypeID(subroleValue) == CFStringGetTypeID()) {
                NSString* subrole = (__bridge NSString*) subroleValue;
                dict[attributeName] = subrole;
                CFRelease(subroleValue);
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXTabsAttribute) {
            // Handle kAXTabsAttribute
        } else if (attribute == (id)kAXTitleAttribute) {
            NSString* axTitle = nil;
            AXError result = AXUIElementCopyAttributeValue(el, kAXTitleAttribute, (void *)&axTitle);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = axTitle;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXTitleUIElementAttribute) {
            // Handle kAXTitleUIElementAttribute
        } else if (attribute == (id)kAXToolbarButtonAttribute) {
            // Handle kAXToolbarButtonAttribute
        } else if (attribute == (id)kAXTopLevelUIElementAttribute) {
            // Handle kAXTopLevelUIElementAttribute
        } else if (attribute == (id)kAXURLAttribute) {
            NSString* url = nil;
            AXError result = AXUIElementCopyAttributeValue(el, kAXURLAttribute, (void *)&url);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = url;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXValueAttribute) {
            NSString* axValue = nil;
            AXError result = AXUIElementCopyAttributeValue(el, kAXValueAttribute, (void *)&axValue);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = axValue;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXValueDescriptionAttribute) {
            // Handle kAXValueDescriptionAttribute
        } else if (attribute == (id)kAXValueIncrementAttribute) {
            // Handle kAXValueIncrementAttribute
        } else if (attribute == (id)kAXValueWrapsAttribute) {
            // Handle kAXValueWrapsAttribute
        } else if (attribute == (id)kAXVerticalScrollBarAttribute) {
            // Handle kAXVerticalScrollBarAttribute
        } else if (attribute == (id)kAXVisibleCharacterRangeAttribute) {
            // Handle kAXVisibleCharacterRangeAttribute
        } else if (attribute == (id)kAXVisibleChildrenAttribute) {
            // Handle kAXVisibleChildrenAttribute
        } else if (attribute == (id)kAXVisibleColumnsAttribute) {
            // Handle kAXVisibleColumnsAttribute
        } else if (attribute == (id)kAXVisibleRowsAttribute) {
            // kAXVisibleRowsAttribute
        } else if (attribute == (id)kAXWindowAttribute) {
            // Handle kAXWindowAttribute
        } else if (attribute == (id)kAXWindowsAttribute) {
            NSArray* wins;
            AXError result = AXUIElementCopyAttributeValue(el, kAXWindowsAttribute, (void*)&wins);
            if (result == kAXErrorSuccess) dict[attributeName] = wins;
            else dict[attributeName] = @[];
        } else if (attribute == (id)kAXYearFieldAttribute) {
            // Handle kAXYearFieldAttribute
        } else if (attribute == (id)kAXZoomButtonAttribute) {
            // Handle kAXZoomButtonAttribute
        } else {//missing attributes
            if (attribute == (id)kAXPIDAttribute) { //fake kAXAttribute, otherwise no way to get pid with elementDict
                pid_t axPID = -1;
                AXUIElementGetPid(el, &axPID);
                dict[attributeName] = @(axPID);
                continue;
            }
            if (attribute == (id)kAXFullscreenAttribute) {
                BOOL val;
                AXError result = AXUIElementCopyAttributeValue(el, kAXFullscreenAttribute, (void*)&val);
                if (result == kAXErrorSuccess) {
                    dict[attributeName] = @(val);
                } else dict[attributeName] = @NO;
                continue;
            }
            if (attribute == (id)kAXStatusLabelAttribute) { //"badge" value / # of notifications
                int val;
                AXError result = AXUIElementCopyAttributeValue(el, kAXStatusLabelAttribute, (void*)&val);
                if (result == kAXErrorSuccess) {
                    dict[attributeName] = @(val);
                } else dict[attributeName] = @0;
            }
            // Default case when attribute is not matched
            dict[attributeName] = @"";
            NSLog(@"attribute %@ DNE", attributeName);
        }
    }
    return dict;
}
+ (NSDictionary*) axInfo:(AXUIElementRef)el {
    NSString *axTitle = nil;
    NSNumber *axIsApplicationRunning;
    pid_t axPID = -1;
    NSString *role;
    NSString *subrole;
    CGSize size;
    if (el) {
        AXUIElementCopyAttributeValue(el, kAXTitleAttribute, (void *)&axTitle);
        axTitle = appAliases[axTitle] ? appAliases[axTitle] : axTitle; //app's with alias work weird (eg: VScode = Code)
        AXUIElementGetPid(el, &axPID);                                                                      //pid
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute, (void*)&role);                                    //role
        AXUIElementCopyAttributeValue(el, kAXSubroleAttribute, (void*)&subrole);                              //subrole
        AXUIElementCopyAttributeValue(el, kAXIsApplicationRunningAttribute, (void *)&axIsApplicationRunning);  //running?
        AXValueRef sizeAxRef;
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute, (CFTypeRef*) &sizeAxRef);
        AXValueGetValue(sizeAxRef, kAXValueCGSizeType, &size);
//        CFRelease(sizeAxRef);
    }
    return [NSDictionary dictionaryWithObjectsAndKeys:
                                !axTitle ? @"" : axTitle, @"title",
                                @([axIsApplicationRunning intValue]), @"running",
                                @(axPID), @"PID",
                                !role ? @"" : role, @"role",
                                !subrole ? @"" : subrole, @"subrole",
                                @(size.width), @"width",
                                @(size.height), @"height"
                                 , nil];
}
+ (NSDictionary*) appInfo:(NSString*) owner {
    NSMutableArray* windows = [owner isEqual:@"Finder"] ? [helperLib getRealFinderWindows] : [helperLib getWindowsForOwner:owner]; //on screen windows
    //hidden & minimized (off screen windows)
    BOOL isHidden = NO;
    BOOL isMinimized = NO;
    if ([helperLib runningAppFromAxTitle:owner].isHidden) isHidden = YES;
    if ([helperLib numWindowsMinimized:owner]) isMinimized = YES;
    //add missing window(s) (a window can be hidden & minimized @ same time (don't want two entries))
    if (!isHidden && isMinimized) [windows addObject:@123456789]; //todo: properly add these two windowTypes to windowNumberList, but works
    return @{
        @"windows": windows,
        @"numWindows": [NSNumber numberWithInt:(int)[windows count]],
        @"isHidden": [NSNumber numberWithBool:isHidden],
        @"isMinimized": [NSNumber numberWithBool:isMinimized],
    };
}

//dock stuff
+ (void) dockSetting:  (CFStringRef) pref : (BOOL) val { //accepts int or Boolean (as int) settings only
    CFPreferencesSetAppValue(pref, !val ? kCFBooleanFalse : kCFBooleanTrue, CFSTR("com.apple.dock"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
}
+ (NSString*) getDockPosition {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* pos = [[defaults persistentDomainForName:@"com.apple.dock"] valueForKey:@"orientation"];
    return pos ? pos : @"bottom";
}
+ (BOOL) dockautohide {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults persistentDomainForName:@"com.apple.dock"] valueForKey:@"autohide"] > 0;
}
+ (void) killDock {
    //(Execute shell command) "killall dock"
    NSString* killCommand = [@"/usr/bin/killall " stringByAppendingString:@"Dock"];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:@[ @"-c", killCommand]];
    [task launch];
}

//event listening
+ (void) listenScreens {CGDisplayRegisterReconfigurationCallback((CGDisplayReconfigurationCallBack) proc, (void*) nil);}
+ (CFMachPortRef) listenMouseDown {return [helperLib listenMask:CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventOtherMouseDown) : (CGEventTapCallBack) handleMouseDown];}
+ (CFMachPortRef) listenMouseUp {return [helperLib listenMask:CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp) | CGEventMaskBit(kCGEventOtherMouseUp) : (CGEventTapCallBack) handleMouseUp];}
+ (CFMachPortRef) listenMouseMove {return [helperLib listenMask:CGEventMaskBit(kCGEventMouseMoved) | CGEventMaskBit(kCGEventOtherMouseDragged) : (CGEventTapCallBack) handleMouseMove];}
+ (CFMachPortRef) listenMask : (CGEventMask) emask : (CGEventTapCallBack) handler {
    CFMachPortRef myEventTap;
    CFRunLoopSourceRef eventTapRLSrc;
    myEventTap = CGEventTapCreate (
//       kCGHIDEventTap, // Catch all events (Before system processes it)
//       kCGAnnotatedSessionEventTap, //Specifies that an event tap is placed at the point where session events have been annotated to flow to an application.
        kCGSessionEventTap, // Catch all events for current user session
//       kCGHeadInsertEventTap, // Append to beginning of EventTap list
        kCGTailAppendEventTap, // Append to end of EventTap list
        kCGEventTapOptionDefault, // handler returns nil to preventDefault
        emask,
        handler,
        nil // We need no extra data in the callback
    );
    eventTapRLSrc = CFMachPortCreateRunLoopSource( //runloop source
        kCFAllocatorDefault,
        myEventTap,
        0
    );
    CFRunLoopAddSource(// Add the source to the current RunLoop
        CFRunLoopGetCurrent(),
//       CFRunLoopGetMain(),
        eventTapRLSrc,
        kCFRunLoopCommonModes
    );
    CFRelease(eventTapRLSrc);
    return myEventTap;

}
+ (void) listenRunningAppsChanged {
    //listeners
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(trackFrontApp:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(trackFrontApp:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackFrontApp:) name:NSApplicationDidBecomeActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackFrontApp:) name:NSApplicationDidResignActiveNotification object:NSApp];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(trackFrontApp:) name:NSApplicationDidHideNotification object:NSApp];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(trackFrontApp:) name:@"com.apple.HIToolbox.menuBarShownNotification" object:nil];
}
@end
