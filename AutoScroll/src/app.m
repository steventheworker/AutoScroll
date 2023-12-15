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
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(appBecameActive:) name: NSApplicationDidBecomeActiveNotification object: nil];
}
+ (void) appBecameActive: (NSNotification*) notification {
    // NSLog(@"app became active"); // triggers when run on xcode onlaunch
    // don't raise prefs if sparkle updater visible (may open on launch (and triggers appBecameActive unintentionally))
    NSArray* windows = [[NSApplication sharedApplication] windows];
    // don't raise mainWindow if app already has a visible app (ignore menubar icon)
    for (NSWindow* cur in windows) if (cur.isVisible) {if (cur.level == NSStatusWindowLevel) continue; else return;}
    // raise main window
    [app openPrefs];
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
+ (void) openPrefs {
    [helperLib.getApp.window setIsVisible: YES];
//    [prefsController render];
    [NSApp activateIgnoringOtherApps: YES];
    [helperLib.getApp.window makeKeyAndOrderFront: nil];

}
@end
