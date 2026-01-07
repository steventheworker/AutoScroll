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
    
//    @"com.jetbrains.intellij",
//    @"com.jetbrains.WebStorm",
//    @"com.jetbrains.PhpStorm",
//    @"com.jetbrains.rubymine",
//    @"com.jetbrains.clion",
//    @"com.jetbrains.goland",
//    @"com.jetbrains.appcode",
//    @"com.jetbrains.pycharm",
    
    /* @"com.apple.Safari", @"org.mozilla.firefoxdeveloperedition" */];
NSString* defaultBlacklistStr(void) {
    NSMutableString* ret = NSMutableString.string;
    for (NSString* appbid in DEFAULT_BLACKLIST) [ret appendString: [NSString stringWithFormat: @"%@\n", appbid]];
    return ret;
}

AXUIElementRef systemWideEl = nil;
@interface AppDelegate ()
//@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
/* ibaction's */
- (IBAction)defaultBlacklistLinkBtn:(id)sender {
    [NSWorkspace.sharedWorkspace openURL: [NSURL URLWithString: @"https://github.com/steventheworker/AutoScroll/blob/main/AutoScroll/AppDelegate.m"]];
}
- (IBAction)checkUncheckMenuIcon:(id)sender {
    [statusItem setVisible: (BOOL) [sender state]];
    [[NSUserDefaults standardUserDefaults] setBool: (BOOL) [sender state] forKey: @"showMenubarIcon"];
}
- (IBAction)openPrefs:(id)sender {[app openPrefs];}
- (IBAction)bindQuitApp:(id)sender {[NSApp terminate:nil];}

/* lifecycle */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [helperLib setSystemWideEl: (systemWideEl = AXUIElementCreateSystemWide())];
    [app init];
    
    //blacklist
    NSString* blacklistVal = [NSUserDefaults.standardUserDefaults objectForKey: @"blacklist"];
    [(NSTextView*)blacklistView.documentView setString: blacklistVal == NULL ? defaultBlacklistStr() : blacklistVal];
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(blacklistDidChange:) name: NSTextDidChangeNotification object: blacklistView.documentView];
}
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

/* events */
- (void) blacklistDidChange: (NSNotification*) notification {
    [autoscroll updateBlacklist];
    [NSUserDefaults.standardUserDefaults setValue: ((NSTextView*)blacklistView.documentView).string forKey: @"blacklist"];
}
- (void) mousedown: (CGEventRef) e : (CGEventType) etype {[app mousedown: e : etype];}
- (void) mouseup: (CGEventRef) e : (CGEventType) etype {[app mouseup: e : etype];}
- (void) mousemove: (CGEventRef) e : (CGEventType) etype {[app mousemove: e : etype];}
@end
