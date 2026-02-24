require "json"

@[Link(ldflags: "-framework Cocoa -framework WebKit -framework Foundation #{__DIR__}/../ext/cocoawebview.m")]
lib Native
  fun nsapp_init : Void*
  fun nsapp_run : Void
  fun nsapp_exit : Void
  # Map the setter functions
  alias CrystalCallback = -> Nil
  fun set_on_terminate(cb : CrystalCallback)
  fun set_on_launch(cb : CrystalCallback)

  alias CrystalMessageCallback = (Void*, LibC::Char*) -> Nil
  fun set_on_webview_message(cb : CrystalMessageCallback)

  alias CrystalStatusItemCallback = (x : Int32, y : Int32, w : Int32, h : Int32) -> Nil
  fun set_on_status_item_click(cb : CrystalStatusItemCallback)

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

  # NSMenu
  fun nsmenu_initialize : Void *
  fun nsmenu_menu_item_set_target(item: Void*, target : Void*) : Void
  fun nsmenu_new_menu : Void*
  fun nsmenu_menu_item_set_action(item: Void*, action : LibC::Char*) : Void
  fun nsmenu_new_menu_item : Void*
  fun nsmenu_new_separator_item : Void*
  fun nsmenu_create_menu_item(title : LibC::Char*, tag : Int32, key : LibC::Char*) : Void*
  fun nsmenu_add_item_to_menu(item: Void*, menu : Void*) : Void
  fun nsmenu_set_submenu_to_menu(submenu: Void*, menu: Void*) : Void
  fun nsmenu_show(menu : Void*) : Void
  fun nsmenu_get_main_menu(menu: Void*) : Void*

  # CocoaStatusItem
  fun statusitem_initialize(image_name : LibC::Char*) : Void*
end

module Cocoawebview
  NSWindowStyleMaskResizable = 8
  NSWindowStyleMaskMiniaturizable = 4
  NSWindowStyleMaskTitled = 1
  NSWindowStyleMaskClosable = 2
  NSWindowStyleMaskFullSizeContentView = (1 << 15)
  NSWindowStyleMaskFullScreen = (1 << 14)

  class CocoaStatusItem
    @@instances = {} of Void* => CocoaStatusItem
    @handle : Void*

    def initialize(image_name : String)
      @handle = Native.statusitem_initialize(image_name)
      @@instances[@handle] = self

      Native.set_on_status_item_click ->(x : Int32, y : Int32, w : Int32, h : Int32) {
        if status = @@instances.values.first?
          status.status_item_did_clicked(x, y, w, h)
        end
      }
    end

    def status_item_did_clicked(x, y, width, height)
      puts "Status item clicked: x: #{x}, y: {y}, screen width: #{w}, screen height: #{h}"
    end
  end

  class NSMenu
    @handle : Void*
    @bindings : Hash(Int32, Proc(Nil))

    def initialize
      @handle = Native.nsmenu_initialize()
      @bindings = {} of Int32 => Proc(Nil)
    end

    def create_menu_item_with(title : String, tag : Int32, key : String, &block)
      @bindings[tag] = block if block
      create_menu_item(title, tag, key)
    end

    def main_menu_bar
      Native.nsmenu_get_main_menu(@handle)
    end

    def new_menu
      Native.nsmenu_new_menu()
    end

    def set_menu_item_target(menu_item : Void*, target : Void*?)
      Native.nsmenu_menu_item_set_target(menu_item, target)
    end

    def set_menu_item_action(menu_item : Void*, action : String)
      Native.nsmenu_menu_item_set_action(menu_item, action)
    end

    def new_menu_item
      Native.nsmenu_new_menu_item()
    end

    def new_separator
      Native.nsmenu_new_separator_item()
    end

    def create_menu_item(title : String, tag : Int32, key : String)
      Native.nsmenu_create_menu_item(title, tag, key)
    end

    def add_item_to_menu(item : Void*, menu : Void*)
      Native.nsmenu_add_item_to_menu(item, menu)
    end

    def set_submenu_to_menu(submenu : Void*, menu : Void*)
      Native.nsmenu_set_submenu_to_menu(submenu, menu)
    end

    def show
      Native.nsmenu_show(@handle)
    end
  end

  class NSApp
    @handle : Void*
    @@instances = {} of Void* => NSApp
    def initialize

      @handle = Native.nsapp_init()
      @@instances[@handle] = self

      Native.set_on_terminate ->() {
        if app = @@instances.values.first?
          app.app_will_exit
        end
      }

      Native.set_on_launch ->() {
        if app = @@instances.values.first?
          app.app_did_launch
        end
      }
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
