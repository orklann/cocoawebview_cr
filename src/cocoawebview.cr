@[Link(ldflags: "-framework Cocoa -framework WebKit -framework Foundation #{__DIR__}/../ext/cocoawebview.m")]
lib Native
  fun add(a : Int32, b : Int32) : Int32
  fun nsapp_init : Void*
  fun nsapp_run : Void
  fun nsapp_exit : Void
  # Map the setter functions
  fun set_on_terminate(cb : -> Void)
  fun set_on_launch(cb : -> Void)
end

module Cocoawebview
  class NSApp
    @handle : Void*
    def initialize
      @handle = Native.nsapp_init()
      Native.set_on_launch(->{ app_did_launch })
      Native.set_on_terminate(->{ app_will_exit })
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

  def self.add(a : Int32, b : Int32)
    Native.add(a, b)
  end
end
