@[Link(ldflags: "-framework Cocoa -framework WebKit -framework Foundation #{__DIR__}/../ext/cocoawebview.m")]
lib Native
  fun add(a : Int32, b : Int32) : Int32
  fun nsapp_init : Void*
  fun nsapp_run : Void
  fun nsapp_exit : Void
end

module Cocoawebview
  class NSApp
    @handle : Void*
    def initialize
      @handle = Native.nsapp_init()
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
