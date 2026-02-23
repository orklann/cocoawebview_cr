#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <stdio.h>

NSApplication *application = nil;

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
    //rb_funcall(app, rb_intern("app_will_exit"), 0);
    NSLog(@"app will exit!");
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    //rb_funcall(app, rb_intern("dock_did_click"), 0);
    NSLog(@"dock did click!");
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    //rb_funcall(app, rb_intern("app_did_launch"), 0);
    NSLog(@"app did launch!");
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
