//
//  AppDelegate.m
//  AutoScroll
//
//  Created by Steven G on 8/19/23.
//

#import "AppDelegate.h"
#import "src/helperLib.h"
#import "src/app.h"
#import "src/globals.h"
#import "src/autoscroll.h"

@interface AppDelegate ()
//@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
- (IBAction)checkUncheckMenuIcon:(id)sender {
    [statusItem setVisible: (BOOL) [sender state]];
    [[NSUserDefaults standardUserDefaults] setBool: (BOOL) [sender state] forKey: @"showMenubarIcon"];
}
- (IBAction)openPrefs:(id)sender {[app openPrefs];}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {[app init];}
- (IBAction)bindQuitApp:(id)sender {[NSApp terminate:nil];}
- (void)applicationWillTerminate:(NSNotification *)aNotification {}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}
- (void) awakeFromNib {
    NSNumber* iconPrefsVal = [NSUserDefaults.standardUserDefaults objectForKey: @"showMenubarIcon"];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
    [[statusItem button] setImage: [NSImage imageNamed:@"menuIcon"]];
    [statusItem setMenu: iconMenu];
    [statusItem setVisible: iconPrefsVal ? iconPrefsVal.boolValue : YES];
    [menuiconCheckbox.cell setIntValue: iconPrefsVal ? iconPrefsVal.boolValue : YES];
}
- (void) mousedown: (CGEventRef) e : (CGEventType) etype {[app mousedown: e : etype];}
- (void) mouseup: (CGEventRef) e : (CGEventType) etype {[app mouseup: e : etype];}
- (void) mousemove: (CGEventRef) e : (CGEventType) etype {[app mousemove: e : etype];}
@end
