#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <stdio.h>

NSApplication *application = nil;

// Define the function pointer type
typedef void (*CrystalCallback)();

typedef void (*CrystalMessageCallback)(void* webview_ptr, const char* msg);

// Global variables to hold the Crystal callbacks
static CrystalCallback on_terminate_cb = NULL;
static CrystalCallback on_launch_cb = NULL;
static CrystalMessageCallback on_webview_message_cb = NULL;

// Setter functions that Crystal will call to "register" the callbacks
void set_on_terminate(CrystalCallback cb) { on_terminate_cb = cb; }
void set_on_launch(CrystalCallback cb) { on_launch_cb = cb; }
void set_on_webview_message(CrystalMessageCallback cb) { on_webview_message_cb = cb; }

typedef struct {
    int width;
    int height;
} SimpleSize;

typedef struct {
    int x;
    int y;
} SimplePoint;

@interface CocoaStatusItem : NSObject {
}

@property (strong, nonatomic) NSStatusItem *statusItem;

- (id)initWithImage:(NSString*)imageName;
@end

@implementation CocoaStatusItem

- (id)initWithImage:(NSString*)imageName {
    // Create the status item
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    // Load image from bundle (ensure it's a template image)
    NSImage *icon = [NSImage imageNamed:imageName];
    icon.template = YES; // Important: allows macOS to auto-adapt for dark/light mode

    // Set the icon on the button
    self.statusItem.button.image = icon;

    // Set action and target
    self.statusItem.button.action = @selector(menuIconClicked:);
    self.statusItem.button.target = self;
    return self;
}


- (void)menuIconClicked:(id)sender {
    NSStatusBarButton *button = self.statusItem.button;
    if (!button) return;

    // Get window and its frame in screen coordinates
    NSWindow *buttonWindow = button.window;
    NSRect frameInScreen = [buttonWindow frame];

    // Get the screen where the icon is located
    NSScreen *screen = [buttonWindow screen];
    NSRect screenRect = [screen frame];

    int x = frameInScreen.origin.x;
    int y = frameInScreen.origin.y;
    int screen_width = screenRect.size.width;
    int screen_height = screenRect.size.height;

    /*rb_funcall(obj, rb_intern("status_item_did_clicked"), 4, x, y, screen_width, screen_height);
    */
}
@end

@interface Menu : NSObject {
    
}

@property (nonatomic, strong) NSMenu *mainMenu;
@end

@implementation Menu

@end

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
    if (on_terminate_cb) {
        on_terminate_cb();
    } else {
        NSLog(@"on_terminate_cb is NULL!");
    }
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

@interface FileDropContainerView : NSView {
    //VALUE rb_cocoawebview;
}
@end

@implementation FileDropContainerView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
    }
    return self;
}

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)prepareForDragOperation:(id<NSDraggingInfo>)sender {
    return YES;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pasteboard = [sender draggingPasteboard];
    NSArray<NSURL *> *fileURLs = [pasteboard readObjectsForClasses:@[[NSURL class]]
                                                           options:@{NSPasteboardURLReadingFileURLsOnlyKey: @YES}];

    //VALUE files = rb_ary_new();
    for (int i = 0; i < fileURLs.count; i++) {
        NSString *filePath = fileURLs[i].path;
        //VALUE ruby_file_path = rb_str_new_cstr([filePath UTF8String]);
        //rb_ary_push(files, ruby_file_path);
    }

    if (fileURLs.count > 0) {
        //rb_funcall(rb_cocoawebview, rb_intern("file_did_drop"), 1, files);
        return YES;
    }
    return NO;
}

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor clearColor] setFill];
    NSRectFill(dirtyRect);
}
@end

@interface CocoaWKWebView : WKWebView
@property (nonatomic, strong) NSEvent *lastMouseDownEvent;
@end

@implementation CocoaWKWebView

- (void)mouseDown:(NSEvent *)event {
    self.lastMouseDownEvent = event;
    [super mouseDown:event];
}
@end

@interface CocoaWebview : NSWindow <WKScriptMessageHandler, WKNavigationDelegate> {
    CocoaWKWebView *webView;
    BOOL showDevTool;
    BOOL shouldMoveTitleButtons;
    /* TODO: Implement fild drop */
    FileDropContainerView *fileDropView;
    int deltaY;
}
- (void)increaseNormalLevel:(int)delta;
- (void)setShouldMoveTitleButtons:(BOOL)flag;
- (void)setDevTool:(BOOL)flag;
- (void)setDeltaY:(int)dy;
- (id)initWithFrame:(NSRect)frame debug:(BOOL)flag style:(int)style moveTitleButtons:(BOOL)moveTitleButtons deltaY:(int)dy hideTitleBar:(BOOL)hideTitleBar;
- (void)eval:(NSString*)code;
- (void)navigate:(NSString*)url;
- (void)dragging;
@end

@implementation CocoaWebview
- (id)initWithFrame:(NSRect)frame debug:(BOOL)flag style:(int)style moveTitleButtons:(BOOL)moveTitleButtons deltaY:(int)dy  hideTitleBar:(BOOL)hideTitleBar{
    self = [super initWithContentRect:frame
                            styleMask:style
                              backing:NSBackingStoreBuffered
                                defer:NO];
    if (self) {
        [self center];
        [self setTitle:@"My Custom Window"];
        [self setDevTool:flag];
        [self setDeltaY:dy];
        if (hideTitleBar) {
            [self setTitlebarAppearsTransparent: YES];
            [self setTitleVisibility:NSWindowTitleHidden];
        } else {
            [self setTitlebarAppearsTransparent: NO];
        }
        [self addWebViewToWindow:self];
        [self setShouldMoveTitleButtons:moveTitleButtons];
        if (moveTitleButtons) {
            [self moveWindowButtonsForWindow:self];
        }
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidResize:)
                                                     name:NSWindowDidResizeNotification
                                                   object:self];
    }
    return self;
}

- (void)increaseNormalLevel:(int)delta {
    [self setLevel:NSNormalWindowLevel + delta];
}

- (void)setDeltaY:(int)dy {
    deltaY = dy;
}

- (void)setShouldMoveTitleButtons:(BOOL)flag {
    shouldMoveTitleButtons = flag;
}

- (void)windowDidResize:(NSNotification *)notification {
    if (shouldMoveTitleButtons) {
        [self moveWindowButtonsForWindow:self];
    }
}

- (void)moveWindowButtonsForWindow:(NSWindow *)window {
    //Close Button
    NSButton *closeButton = [window standardWindowButton:NSWindowCloseButton];
    [closeButton setFrameOrigin:NSMakePoint(closeButton.frame.origin.x + 10, closeButton.frame.origin.y - deltaY)];

    //Minimize Button
    NSButton *minimizeButton = [window standardWindowButton:NSWindowMiniaturizeButton];
    [minimizeButton setFrameOrigin:NSMakePoint(minimizeButton.frame.origin.x + 10, minimizeButton.frame.origin.y - deltaY)];

    //Zoom Button
    NSButton *zoomButton = [window standardWindowButton:NSWindowZoomButton];
    [zoomButton setFrameOrigin:NSMakePoint(zoomButton.frame.origin.x + 10, zoomButton.frame.origin.y - deltaY)];
}

- (void)close {
    [self orderOut:nil]; // Hide instead of destroy
}

- (void)windowWillClose:(NSNotification *)notification {
    // Prevent release by hiding the window instead
    [notification.object orderOut:nil];
}

- (void)dragging {
    NSEvent *event = [NSApp currentEvent];
    [self performWindowDragWithEvent:event];
}

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:@"native"]) {
        const char *body = [message.body UTF8String];
        if (on_webview_message_cb) {
            // 'self' here refers to the specific CocoaWebview instance 
            // that received the message
            on_webview_message_cb((__bridge void *)self, [message.body UTF8String]);
        }
    }
}

- (void)setDevTool:(BOOL)flag {
    showDevTool = flag;
}

- (void)navigate:(NSString*)url {
    NSURL *url_ns = [NSURL URLWithString:url];
    NSURLRequest *request = [NSURLRequest requestWithURL:url_ns];
    [webView loadRequest:request];
}

- (void)eval:(NSString*)code {
    [webView evaluateJavaScript:code completionHandler:^(id result, NSError *error) {
        if (error) {
            NSLog(@"JavaScript error: %@", error);
        }
    }];
}

- (void)addWebViewToWindow:(NSWindow *)window {
    NSRect contentRect = [[window contentView] bounds];

    fileDropView = [[FileDropContainerView alloc] initWithFrame:contentRect];
    fileDropView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    WKUserContentController *userContentController = [[WKUserContentController alloc] init];
    [userContentController addScriptMessageHandler:self name:@"native"];

    // Create a configuration if needed
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];

    [[config preferences] setValue:@YES forKey:@"fullScreenEnabled"];

    config.userContentController = userContentController;
    if (showDevTool) {
        [[config preferences] setValue:@YES forKey:@"developerExtrasEnabled"];
    }

    [[config preferences] setValue:@YES forKey:@"javaScriptCanAccessClipboard"];

    [[config preferences] setValue:@YES forKey:@"DOMPasteAllowed"];

    // Create the WKWebView with the configuration
    webView = [[CocoaWKWebView alloc] initWithFrame:contentRect configuration:config];

    // Enable autoresizing
    [webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

    // Load a URL
    /*
    NSURL *url = [NSURL URLWithString:@"https://www.apple.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [webView loadRequest:request];
    */

    // Add to window's contentView
    [[window contentView] addSubview: webView];
    [[window contentView] addSubview:fileDropView positioned:NSWindowAbove relativeTo:webView];

    webView.navigationDelegate = self;
}

// Called when the web view finishes loading
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // TODO: Call crystal callback
    //rb_funcall(rb_cocoawebview, rb_intern("webview_did_load"), 0);
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

id webview_initialize(bool debug, int style, bool move_title_buttons, int delta_y, bool hide_title_bar) {
    CocoaWebview *webview = [[CocoaWebview alloc] 
        initWithFrame:NSMakeRect(100, 100, 400, 500) 
        debug:debug 
        style:style 
        moveTitleButtons:move_title_buttons
        deltaY:delta_y 
        hideTitleBar:hide_title_bar];
    [webview setReleasedWhenClosed:NO];
    return webview;
}

void webview_show(void *webview_ptr) {
    CocoaWebview *webview = (CocoaWebview *)webview_ptr;
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [webview makeKeyAndOrderFront:nil];
}

void webview_eval(void *webview_ptr, const char *js_code) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    NSString *ns_js = [NSString stringWithUTF8String:js_code];
    
    [webview eval:ns_js];
}

void webview_set_size(void *webview_ptr, int width, int height) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    
    NSRect frame = [webview frame];
    frame.size.width = (CGFloat)width;
    frame.size.height = (CGFloat)height;
    
    [webview setFrame:frame display:YES];
}

SimpleSize webview_get_size(void *webview_ptr) {
    NSView *webview = (__bridge NSView *)webview_ptr;
    NSRect frame = [webview frame];
    
    SimpleSize s;
    s.width = (int)frame.size.width;
    s.height = (int)frame.size.height;
    return s;
}

void webview_set_pos(void *webview_ptr, int x, int y) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    NSPoint newOrigin = NSMakePoint(x, y);
    [webview setFrameOrigin:newOrigin];
}

SimplePoint webview_get_pos(void *webview_ptr) {
    NSView *webview = (__bridge NSView *)webview_ptr;
    NSRect frame = [webview frame];
    int x = frame.origin.x;
    int y = frame.origin.y;
    SimplePoint p;
    p.x = x;
    p.y = y;
    return p;
}

void webview_dragging(void *webview_ptr) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    [webview dragging];
}

void webview_center(void *webview_ptr) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    [webview center];
}

void webview_hide(void *webview_ptr) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    [webview orderOut:nil];
}

Menu* nsmenu_initialize() {
  Menu *menu = [[Menu alloc] init];
  menu.mainMenu = [NSMenu new];
  return menu;
}

void nsmenu_menu_item_set_target(NSMenuItem *menu_item, id target) {
    menu_item.target = target;
}

NSMenu* nsmenu_new_menu() {
    NSMenu *menu = [NSMenu new];
    return menu;
}

void nsmenu_menu_item_set_action(NSMenuItem *menu_item, const char* action) {
    NSString *action_ns = [[NSString alloc] initWithCString:action encoding:NSUTF8StringEncoding];
    menu_item.action = NSSelectorFromString(action_ns); 
}

NSMenuItem* nsmenu_new_menu_item() {
    NSMenuItem *menuItem = [NSMenuItem new];
    return menuItem;
}

NSMenuItem *nsmenu_new_separator_item() {
    NSMenuItem *menuItem = [NSMenuItem separatorItem];
    return menuItem;
}

NSMenuItem *nsmenu_create_menu_item(const char* title, int tag, const char* key) {
    NSString *title_ns = [[NSString alloc] initWithCString:title encoding:NSUTF8StringEncoding];

    NSString *key_ns = [[NSString alloc] initWithCString:key encoding:NSUTF8StringEncoding];

    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title_ns
                                                          action:@selector(handleMenuAction:) 
                                                          keyEquivalent:key_ns];

    [menuItem setTag:tag];
    return menuItem;
}

void nsmenu_add_item_to_menu(NSMenuItem *item, NSMenu *menu) {
    [menu addItem:item];
}

/* NOTE: menu is class NSMenuItem */
void nsmenu_set_submenu_to_menu(NSMenu *submenu, NSMenuItem *menu) {
    [menu setSubmenu:submenu];
}

void nsmenu_show(Menu *menu) {
    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app setMainMenu:menu.mainMenu];
}

NSMenu *nsmenu_get_main_menu(Menu *menu) {
    return menu.mainMenu;
}

CocoaStatusItem *statusitem_initialize(const char* image_name) {
    NSString *ns_image_name = [[NSString alloc] initWithCString:image_name encoding:NSUTF8StringEncoding];
    CocoaStatusItem *statusItem = [[CocoaStatusItem alloc] initWithImage:ns_image_name];
    return statusItem;
}
