#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <stdio.h>

NSApplication *application = nil;

// Define the function pointer type
typedef void (*CrystalCallback)();

// Global variables to hold the Crystal callbacks
static CrystalCallback on_terminate_cb = NULL;
static CrystalCallback on_launch_cb = NULL;

// Setter functions that Crystal will call to "register" the callbacks
void set_on_terminate(CrystalCallback cb) { on_terminate_cb = cb; }
void set_on_launch(CrystalCallback cb) { on_launch_cb = cb; }

@interface AppDelegate : NSObject <NSApplicationDelegate> {

}
@end

@implementation AppDelegate

- (void)handleMenuAction:(id)sender {
    NSMenuItem *item = (NSMenuItem *)sender;
    NSInteger tag = [item tag];
    //VALUE rb_tag = INT2NUM(tag);
    //rb_funcall(rb_menu, rb_intern("handle_menu_action"), 1, rb_tag);
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    if (on_terminate_cb) on_terminate_cb();
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    //rb_funcall(app, rb_intern("dock_did_click"), 0);
    NSLog(@"dock did click!");
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    if (on_launch_cb) on_launch_cb();
}
@end

NSApplication* nsapp_init() {
  application = [NSApplication sharedApplication];
  AppDelegate *delegate = [[AppDelegate alloc] init];
  [application setDelegate:delegate];
  return application;
}

void nsapp_run() {
    [application run];
}

void nsapp_exit() {
    [[NSApplication sharedApplication] terminate:nil];
}

int add(int a, int b) {
    NSLog(@"Calling add!");
    return a + b;
}
