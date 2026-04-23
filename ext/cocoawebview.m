#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <stdio.h>

NSApplication *application = nil;

// Define the function pointer type
typedef void (*CrystalCallback)();

typedef void (*CrystalMessageCallback)(void* webview_ptr, const char* msg);

typedef void (*CrystalStatusItemCallback)(int x, int y, int screen_width, int screen_height);

typedef void (*CrystalMenuItemCallback)(int tag);
typedef void (*CrystalTimerCallback)(void* timer_ptr);

typedef void (*CrystalFocusCallback)(void* webview_ptr);

static CrystalTimerCallback on_timer_tick_cb = NULL;

void set_on_timer_tick(CrystalTimerCallback cb) { on_timer_tick_cb = cb; }

static CrystalFocusCallback on_window_blur_cb = NULL;
void set_on_window_blur(CrystalFocusCallback cb) { on_window_blur_cb = cb; }

// Global variables to hold the Crystal callbacks
static CrystalCallback on_terminate_cb = NULL;
static CrystalCallback on_theme_changed_cb = NULL;
static CrystalCallback on_launch_cb = NULL;
static CrystalMessageCallback on_webview_message_cb = NULL;
static CrystalStatusItemCallback on_status_item_clicked_cb = NULL;
static CrystalMenuItemCallback on_menu_item_clicked_cb = NULL;

// Setter functions that Crystal will call to "register" the callbacks
void set_on_terminate(CrystalCallback cb) { on_terminate_cb = cb; }
void set_on_launch(CrystalCallback cb) { on_launch_cb = cb; }
void set_on_webview_message(CrystalMessageCallback cb) { on_webview_message_cb = cb; }
void set_on_status_item_click(CrystalStatusItemCallback cb) { on_status_item_clicked_cb = cb; }
void set_on_theme_changed(CrystalCallback cb) { on_theme_changed_cb = cb; }
void set_on_menu_item_clicked(CrystalMenuItemCallback cb) { on_menu_item_clicked_cb = cb; }

void (*on_webview_finished_load)(void*) = NULL;

void set_on_webview_finished_load(void (*cb)(void*)) {
    on_webview_finished_load = cb;
}


typedef struct {
    int width;
    int height;
} SimpleSize;

typedef struct {
    int x;
    int y;
} SimplePoint;

// Implement the Bridge Class to handle the NSTimer selector
@interface TimerBridge : NSObject
- (void)timerFired:(NSTimer *)timer;
@end

@implementation TimerBridge
- (void)timerFired:(NSTimer *)timer {
    if (on_timer_tick_cb) {
        // Pass the timer pointer back so Crystal knows which timer fired
        on_timer_tick_cb((__bridge void *)timer);
    }
}
@end

static TimerBridge *timerBridge = nil;

@interface CocoaStatusItem : NSObject {
}

@property (strong, nonatomic) NSStatusItem *statusItem;

- (id)initWithImage:(NSString*)imageName;
- (id)initWithImageBase64:(NSString*)base64string;
- (void)setIconByBase64:(NSString*)base64String;
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

- (id)initWithImageBase64:(NSString*)base64string {
    self = [super init];
    if (self) {
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

        NSData *data = [[NSData alloc] initWithBase64EncodedString:base64string options:NSDataBase64DecodingIgnoreUnknownCharacters];
        
        if (data) {
            NSImage *icon = [[NSImage alloc] initWithData:data];

            NSImageRep *rep = [[icon representations] firstObject];
            if (rep) {

                // 1. Get the actual physical pixel dimensions
                CGFloat pixelWidth = (CGFloat)[rep pixelsWide];
                CGFloat pixelHeight = (CGFloat)[rep pixelsHigh];

                // 2. Get the scale factor of the main screen (or the button's screen)
                // 2.0 for Retina, 1.0 for Standard
                CGFloat scale = 1.0;
                if (self.statusItem.button.window.screen) {
                    scale = self.statusItem.button.window.screen.backingScaleFactor;
                } else {
                    scale = [[NSScreen mainScreen] backingScaleFactor];
                }

                // 3. Set the logical point size based on the screen's density
                // If pixels=44 and scale=2.0, size=22pt (Correct Retina)
                // If pixels=22 and scale=1.0, size=22pt (Correct Standard)
                [icon setSize:NSMakeSize(pixelWidth / scale, pixelHeight / scale)];
            }
            
            icon.template = YES; 
            self.statusItem.button.image = icon;
        }

        self.statusItem.button.action = @selector(menuIconClicked:);
        self.statusItem.button.target = self;
    }
    return self;
}

- (void)setIconByBase64:(NSString*)base64String {
    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
    
    if (data) {
        NSImage *icon = [[NSImage alloc] initWithData:data];
        if (icon) {
            NSImageRep *rep = [[icon representations] firstObject];
            if (rep) {
                // 1. Get the actual physical pixel dimensions
                CGFloat pixelWidth = (CGFloat)[rep pixelsWide];
                CGFloat pixelHeight = (CGFloat)[rep pixelsHigh];

                // 2. Get the scale factor of the main screen (or the button's screen)
                // 2.0 for Retina, 1.0 for Standard
                CGFloat scale = 1.0;
                if (self.statusItem.button.window.screen) {
                    scale = self.statusItem.button.window.screen.backingScaleFactor;
                } else {
                    scale = [[NSScreen mainScreen] backingScaleFactor];
                }

                // 3. Set the logical point size based on the screen's density
                // If pixels=44 and scale=2.0, size=22pt (Correct Retina)
                // If pixels=22 and scale=1.0, size=22pt (Correct Standard)
                [icon setSize:NSMakeSize(pixelWidth / scale, pixelHeight / scale)];
            }

            // Standard macOS menu bar icons are usually 18x18 points
            icon.template = NO; 
            
            // Update the existing button image
            self.statusItem.button.image = icon;
        }
    }
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

    if (on_status_item_clicked_cb) {
        on_status_item_clicked_cb(x, y, screen_width, screen_height);
    }
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
    if (on_menu_item_clicked_cb) {
        on_menu_item_clicked_cb(tag);
    }
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

// Handle the theme change
- (void)observeValueForKeyPath:(NSString *)keyPath 
                      ofObject:(id)object 
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change 
                       context:(void *)context {
    
    if ([keyPath isEqualToString:@"effectiveAppearance"]) {
        if (on_theme_changed_cb) {
            on_theme_changed_cb();
        } else {
            NSLog(@"on_theme_changed_cb is NULL!");
        }
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [[NSApp self] addObserver:self 
                   forKeyPath:@"effectiveAppearance" 
                      options:NSKeyValueObservingOptionNew 
                      context:nil];
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

@interface CocoaWebview : NSWindow <WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate> {
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
        [self setDelegate:self];
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
    }
    return self;
}

- (void)windowDidResignKey:(NSNotification *)notification {
    if (on_window_blur_cb) {
        on_window_blur_cb((__bridge void *)self);
    }
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
    if (on_webview_finished_load != NULL) {
        on_webview_finished_load((void *)self); 
    }
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


char* nsapp_get_app_icon(const char* app_path) {
    NSString *app_path_ns = [[NSString alloc] initWithCString:app_path encoding:NSUTF8StringEncoding];

    // 1. Get icon for the app bundle
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:app_path_ns];
    if (!icon) return NULL;

    // Optional: set desired size
    [icon setSize:NSMakeSize(256, 256)];

    // 2. Convert NSImage to PNG data
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
        initWithData:[icon TIFFRepresentation]];

    NSData *pngData = [rep representationUsingType:NSBitmapImageFileTypePNG
                                        properties:@{}];
    if (!pngData) return NULL;

    // 3. Encode to Base64 string
    NSString *base64 = [pngData base64EncodedStringWithOptions:0];

    return strdup([base64 UTF8String]);
}

bool nsapp_is_retina() {
    // We check the main screen's backingScaleFactor. 
    // 1.0 = Standard, 2.0 = Retina
    CGFloat scale = [[NSScreen mainScreen] backingScaleFactor];
    return scale > 1.0;
}

const char* nsapp_get_bundle_path() {
    NSString *path = [[NSBundle mainBundle] resourcePath];
    if (!path) return NULL;
    return strdup([path UTF8String]);
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

void webview_navigate(void *webview_ptr, const char *url) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;
    NSString *ns_url = [NSString stringWithUTF8String:url];
    
    [webview navigate:ns_url];
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

bool webview_is_visible(void *webview_ptr) {
    CocoaWebview *webview = (__bridge CocoaWebview *)webview_ptr;

    if ([webview isVisible]) {
        return true;
    } else {
        return false;
    }
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

CocoaStatusItem *statusitem_initialize_base64(const char* base64_str) {
    NSString *ns_base64 = [[NSString alloc] initWithCString:base64_str encoding:NSUTF8StringEncoding];
    CocoaStatusItem *statusItem = [[CocoaStatusItem alloc] initWithImageBase64:ns_base64];
    return statusItem;
}

void statusitem_set_icon_base64(void *status_item_ptr, const char* base64_str) {
    CocoaStatusItem *statusItem = (__bridge CocoaStatusItem *)status_item_ptr;
    NSString *ns_base64 = [NSString stringWithUTF8String:base64_str];
    
    [statusItem setIconByBase64:ns_base64];
}

void* nstimer_create(double interval, bool repeats) {
    if (!timerBridge) timerBridge = [[TimerBridge alloc] init];
    
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                      target:timerBridge
                                                    selector:@selector(timerFired:)
                                                    userInfo:nil
                                                     repeats:repeats];
    // Keep it alive in the current run loop
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    return (__bridge void *)timer;
}

void nstimer_invalidate(void* timer_ptr) {
    NSTimer *timer = (__bridge NSTimer *)timer_ptr;
    [timer invalidate];
}
