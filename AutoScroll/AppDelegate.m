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

NSArray* DEFAULT_BLACKLIST = @[
    @"md.obsidian",
    @"com.microsoft.VSCode",
    @"com.microsoft.VSCodeInsiders",
    @"com.visualstudio.code.oss",
    @"com.barebones.bbedit",
    @"com.jetbrains.intellij",
    @"com.jetbrains.WebStorm",
    @"com.jetbrains.PhpStorm",
    @"com.jetbrains.rubymine",
    @"com.jetbrains.clion",
    @"com.jetbrains.goland",
    @"com.jetbrains.appcode",
    @"com.jetbrains.pycharm",
    /* @"com.apple.Safari", @"org.mozilla.firefoxdeveloperedition" */];

@interface AppDelegate ()
//@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
- (IBAction)defaultBlacklistLinkBtn:(id)sender {
    NSButton* button = (NSButton*)sender;
    [NSWorkspace.sharedWorkspace openURL: [NSURL URLWithString: @"https://github.com/steventheworker/AutoScroll/blob/main/AutoScroll/AppDelegate.m"]];
}
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
