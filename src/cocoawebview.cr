require "json"

@[Link(ldflags: "-framework Cocoa -framework WebKit -framework Foundation #{__DIR__}/../ext/cocoawebview.m")]
lib Native
  fun nsapp_init : Void*
  fun nsapp_run : Void
  fun nsapp_exit : Void
  # Map the setter functions
  fun set_on_terminate(cb : -> Void)
  fun set_on_launch(cb : -> Void)

  alias CrystalMessageCallback = (Void*, LibC::Char*) -> Nil
  fun set_on_webview_message(cb : CrystalMessageCallback)

  fun webview_initialize(
    debug : Bool,
    style : Int32,
    move_buttons : Bool,
    delta_y : Int32,
    hide_title_bar : Bool
  ) : Void*

  fun webview_show(ptr : Void*)
  fun webview_center(ptr : Void*)
  fun webview_hide(ptr : Void*)
  fun webview_eval(ptr : Void*, js : LibC::Char*) : Void

  fun webview_set_size(ptr : Void*, width : Int32, height : Int32) : Void

  struct SimpleSize
    width : Int32
    height : Int32
  end

  fun webview_get_size(ptr : Void*) : SimpleSize

  fun webview_set_pos(ptr : Void*, x : Int32, y : Int32) : Void

  struct SimplePoint
    x : Int32
    y : Int32
  end

  fun webview_get_pos(ptr : Void*) : SimplePoint

  fun webview_dragging(ptr : Void*) : Void
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
    @bindings = {} of String => (Array(JSON::Any) -> Nil)
    # Store all instances in a hash mapped by their C pointer
    @@instances = {} of Void* => CocoaWebview

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

      @@instances[@webview_ptr] = self
      Native.set_on_webview_message ->(ptr : Void*, c_str : LibC::Char*) {
        # Use the pointer provided by C to find the specific Crystal object
        if webview = @@instances[ptr]?
          webview.webview_msg_handler(c_str)
        else
          puts "Warning: Received message for unknown webview pointer: #{ptr}"
        end
      }
    end

    # This is the instance method you wanted to use
    def webview_msg_handler(c_str : LibC::Char*)
      msg = String.new(c_str)
      data = JSON.parse(msg)

      # We use .as_s and .as_a to tell Crystal these are Strings and Arrays
      function_name = data["function"].as_s
      args = data["args"].as_a

      if callback = @bindings[function_name]?
        # Note: In Crystal, you cannot splat (*args) into a Proc call
        # as easily as Ruby because Proc arguments are typed and fixed.
        # Usually, you'd pass the JSON::Any array directly to the callback.
        callback.call(args)
      end
    end

    def bind(name : String, arg_count : Int32, &block : Array(JSON::Any) -> Nil)
      # 1. Generate the JS argument string (e.g., "arg1, arg2")
      args_list = (1..arg_count).map { |i| "arg#{i}" }.join(", ")

      # 2. Construct the JavaScript bridge code
      js_code = <<-JS
        function #{name}(#{args_list}) {
          const body = {
            "function": "#{name}",
            "args": [#{args_list}]
          };
          window.webkit.messageHandlers.native.postMessage(JSON.stringify(body));
        }
      JS

      # 3. Store the block in our bindings hash
      @bindings[name] = block

      # 4. Inject the JS into the webview
      self.eval(js_code)
    end

    def show
      Native.webview_show(@webview_ptr)
    end

    def hide
      Native.webview_hide(@webview_ptr)
    end

    def center
      Native.webview_center(@webview_ptr)
    end

    def eval(code : String)
      Native.webview_eval(@webview_ptr, code.to_unsafe)
    end

    def set_size(width : Int32, height : Int32)
      Native.webview_set_size(@webview_ptr, width, height)
    end

    def get_size : Array(Int32)
      c_size = Native.webview_get_size(@webview_ptr)
      [c_size.width, c_size.height]
    end

    def set_pos(x : Int32, y : Int32)
      Native.webview_set_pos(@webview_ptr, x, y)
    end

    def get_pos : Array(Int32)
      c_point = Native.webview_get_pos(@webview_ptr)
      [c_point.x, c_point.y]
    end

    def dragging
      Native.webview_dragging(@webview_ptr)
    end

    def finalize
      # NOTE: TODO later?
      # You might need a C function to release the Objective-C object
    end
  end
end
