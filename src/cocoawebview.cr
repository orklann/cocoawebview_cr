@[Link(ldflags: "-framework Cocoa -framework WebKit -framework Foundation #{__DIR__}/../ext/cocoawebview.m")]
lib Native
  fun add(a : Int32, b : Int32) : Int32
  fun nsapp_init : Void*
  fun nsapp_run : Void
  fun nsapp_exit : Void
  # Map the setter functions
  fun set_on_terminate(cb : -> Void)
  fun set_on_launch(cb : -> Void)

  fun webview_initialize(
    debug : Bool,
    style : Int32,
    move_buttons : Bool,
    delta_y : Int32,
    hide_title_bar : Bool
  ) : Void*

  fun webview_show(ptr : Void*)
  fun webview_eval(ptr : Void*, js : LibC::Char*) : Void

  fun webview_set_size(ptr : Void*, width : Int32, height : Int32) : Void
end

module Cocoawebview
  NSWindowStyleMaskResizable = 8
  NSWindowStyleMaskMiniaturizable = 4
  NSWindowStyleMaskTitled = 1
  NSWindowStyleMaskClosable = 2
  NSWindowStyleMaskFullSizeContentView = (1 << 15)
  NSWindowStyleMaskFullScreen = (1 << 14)

  class NSApp
    @handle : Void*
    def initialize
      @handle = Native.nsapp_init()
      Native.set_on_launch(app_did_launch)
      Native.set_on_terminate(app_will_exit)
    end

    def app_did_launch
      puts "Crystal: Application has finished launching!"
    end

    def app_will_exit
      puts "Crystal: Application is shutting down..."
    end

    def run
      Native.nsapp_run
    end

    def exit
      Native.nsapp_exit
    end
  end

  class CocoaWebview
    @webview_ptr : Void*
    @vars = {} of String => String # Equivalent to rb_hash_new
    @bindings = {} of String => String

    def self.create(debug = false, min = true, resize = true, close = true, move_title_buttons = false, delta_y = 10, hide_title_bar = true, &block : -> _)
      style = NSWindowStyleMaskTitled | NSWindowStyleMaskFullSizeContentView

      style = style | NSWindowStyleMaskMiniaturizable if min
      style = style | NSWindowStyleMaskResizable if resize
      style = style | NSWindowStyleMaskClosable if close

      if hide_title_bar
        style &= ~NSWindowStyleMaskFullScreen
      end

      webview = new(debug, style, move_title_buttons, delta_y, hide_title_bar)
      #webview.callback = block
      webview
    end

    def initialize(debug : Bool, style : Int32, move_title_buttons : Bool, delta_y : Int32, hide_title_bar : Bool)
      @webview_ptr = Native.webview_initialize(
        debug,
        style,
        move_title_buttons,
        delta_y,
        hide_title_bar
      )

      if @webview_ptr.null?
        raise "Failed to initialize CocoaWebview"
      end
    end

    def show
      Native.webview_show(@webview_ptr)
    end

    def eval(code : String)
      Native.webview_eval(@webview_ptr, code.to_unsafe)
    end

    def set_size(width : Int32, height : Int32)
      Native.webview_set_size(@webview_ptr, width, height)
    end

    def finalize
      # NOTE: TODO later?
      # You might need a C function to release the Objective-C object
    end
  end

  def self.add(a : Int32, b : Int32)
    Native.add(a, b)
  end
end
