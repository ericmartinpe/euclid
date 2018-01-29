# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("net/http")


module Euclid

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
        msg += "Euclid #{Euclid::VERSION}\n"
        msg += "SketchUp #{Sketchup.version} #{Sketchup.is_64bit? ? '64-bit' : '32-bit'}#{Sketchup.is_pro? ? ' Pro' : ''}\n"
        msg += "Ruby #{RUBY_VERSION} #{RUBY_PLATFORM}\n"

        UI.messagebox(msg, MB_MULTILINE, "Euclid - Error Notification")
      else
        # Not a Euclid bug!
      end
    end
  end


  def self.check_for_update(verbose = true)
    puts "Checking for update..."

    latest_version = nil

    begin
      uri = URI.parse("https://bigladdersoftware.com/updates/euclid-latest-version")
      response = Net::HTTP.get(uri).strip
      latest_version = Gem::Version.new(response) if (not response.empty?)
    rescue
      # Something failed, e.g., no internet connection, website down, or malformed version number.
    end

    puts "installed_version=#{Euclid::VERSION}"
    puts "latest_version=#{latest_version}"

    if (latest_version)
      skip_version = LegacyOpenStudio::Plugin.read_pref('Skip Update')

      if (latest_version > Gem::Version.new(Euclid::VERSION))
        if (latest_version.to_s != skip_version or verbose)
          button = UI.messagebox("A newer version (#{latest_version}) of Euclid is ready for download.\n" +
            "Do you want to update to the newer version?\n\n" +
            "Click YES to visit the Euclid website to get the download.\n" +
            "Click NO to skip this version and not ask you again.\n" +
            "Click CANCEL to remind you again next time.", MB_YESNOCANCEL)
          if (button == 6)  # YES
            UI.openURL("https://bigladdersoftware.com/projects/euclid")
          elsif (button == 7)  # NO
            LegacyOpenStudio::Plugin.write_pref('Skip Update', latest_version.to_s)
          end
        end

      elsif (verbose)
        UI.messagebox("You currently have the latest version of Euclid.")
      end

    elsif (verbose)  # Could not read the current version
      button = UI.messagebox("Euclid was unable to connect to the update server.\nCheck your internet connection and try again later.", MB_OK)
      if (button == 4)
        check_for_update(verbose)
      end
    end

    return(nil)
  end

end
