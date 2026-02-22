@[Link(ldflags: "#{__DIR__}/../ext/cocoawebview.c")]
lib Native
  fun add(a : Int32, b : Int32) : Int32
end

module Cocoawebview
  VERSION = "0.1.0"
  def self.add(a : Int32, b : Int32)
    Native.add(a, b)
  end
end
