# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.


module EuclidExtension

  def self.trace_exceptions
    TracePoint.trace(:raise) do |trace|
      exception = trace.raised_exception

      if (trace.path.include?(__dir__))
        msg = "Sorry...the Euclid extension has encountered an error. "
        msg += "This error may cause unpredictable behavior in the extension--continue this session with caution! "
        msg += "It would probably be a good idea to exit SketchUp and start again.\n\n"

        msg += "For help, please email us at <info@bigladdersoftware.com>.\n\n"

        msg += "When reporting a problem, please copy the information below into your email (scroll down):\n\n"

        msg += "ERROR:\n"
        msg += exception.class.to_s + "\n"
        msg += exception.message + "\n\n"

        msg += "BACKTRACE:\n"
        exception.backtrace.each { |stack_call| msg += stack_call + "\n" }

        msg += "\nCONFIGURATION:\n"
        msg += "Euclid #{EuclidExtension::VERSION}\n"
        msg += "SketchUp #{Sketchup.version} #{Sketchup.is_64bit? ? '64-bit' : '32-bit'}#{Sketchup.is_pro? ? ' Pro' : ''}\n"
        msg += "Ruby #{RUBY_VERSION} #{RUBY_PLATFORM}\n"

        UI.messagebox(msg, MB_MULTILINE, EUCLID_EXTENSION_NAME + " - Error Notification")
      else
        # Not a Euclid bug!
      end
    end
  end

end
