# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("net/http")


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

        UI.messagebox(msg, MB_MULTILINE, "Euclid - Error Notification")
      else
        # Not a Euclid bug!
      end
    end
  end


  def self.check_for_update(verbose = true)
    puts "Checking for update..."

    begin
      latest_version = Net::HTTP.get("bigladdersoftware.com", "/updates/euclid-latest-version")
    rescue  # Something failed, e.g., no internet connection or website down
      latest_version = nil
    end

    puts "installed_version=#{EuclidExtension::VERSION}"
    puts "latest_version=#{latest_version}"

    if (latest_version)
      # Version numbering scheme is (major).(minor).(maintenance).(build), e.g. 0.9.4.1
      installed_version_key = ''; EuclidExtension::VERSION.split('.').each { |e| installed_version_key += e.rjust(4, '0') }
      latest_version_key = ''; latest_version.split('.').each { |e| latest_version_key += e.rjust(4, '0') }
      skip_version_key = LegacyOpenStudio::Plugin.read_pref('Skip Update')

      if (installed_version_key < latest_version_key)
        if (latest_version_key != skip_version_key or verbose)
          button = UI.messagebox("A newer version (" + latest_version + ") of Euclid is ready for download.\n" +
            "Do you want to update to the newer version?\n\n" +
            "Click YES to visit the Euclid website to get the download.\n" +
            "Click NO to skip this version and not ask you again.\n" +
            "Click CANCEL to remind you again next time.", MB_YESNOCANCEL)
          if (button == 6)  # YES
            UI.openURL("http://bigladdersoftware.com/projects/euclid")
          elsif (button == 7)  # NO
            LegacyOpenStudio::Plugin.write_pref('Skip Update', newest_version_key)
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
