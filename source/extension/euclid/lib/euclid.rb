# Copyright (c) 2017-2019 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

module Euclid

  def self.trace_exceptions
    TracePoint.trace(:raise) do |trace|
      exception = trace.raised_exception

      if (trace.path.include?(__dir__))
        msg = "Sorry...the Euclid extension has encountered an error. "
        msg += "This error may cause unpredictable behavior in the extension--continue this session with caution! "
        msg += "It would probably be a good idea to exit SketchUp and start again.\n\n"

        msg += "For help, please email us at <euclid@bigladdersoftware.com>.\n\n"

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

    update_url = "https://bigladdersoftware.com/updates/euclid-latest-version.html"

    if (Gem::Version.new(Sketchup.version) > Gem::Version.new("17"))
      # SketchUp 2017 and later includes built-in HTTP request which works better asynchronously.
      request = Sketchup::Http::Request.new(update_url)
      request.start do |request, response|
        body = response.body
        if (match_data = body.match(/id="version" value="(.*)"/))
          version = match_data.captures.first
        else
          version = nil
        end
        on_update_response(version, verbose)
      end

    else
      # Use a web dialog to get the latest version number--this is the only way that works on SketchUp 2016.
      # NOTE: 0 width and height makes the dialog invisible; must have resize set to false also.
      web_dialog = UI::WebDialog.new("", false, nil, 0, 0, 0, 0, false)

      # If page doesn't load in 5 seconds, call 'on_update_response' anyway.
      timer_id = UI.start_timer(5, false) {
        on_update_response(nil, verbose)
        web_dialog.close if (web_dialog and web_dialog.visible?)
      }

      # Second timer to stop the first timer from repeating:
      # http://ruby.sketchup.com/UI.html#start_timer-class_method
      # "Note that there is a bug that if you open a modal window in a non-repeating timer the timer will repeat until the window is closed."
      UI.start_timer(6, false) { UI.stop_timer(timer_id) }

      web_dialog.add_action_callback("on_load") {
        UI.stop_timer(timer_id)
        version = web_dialog.get_element_value("version")
        on_update_response(version, verbose)
        web_dialog.close if (web_dialog and web_dialog.visible?)
      }
      web_dialog.set_url(update_url)
      web_dialog.show
    end
  end


  def self.on_update_response(version, verbose)
    if (version.nil? or version.strip.empty?)
      latest_version = nil
    else
      latest_version = Gem::Version.new(version)
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
      UI.messagebox("Euclid was unable to connect to the update server.\nCheck your internet connection and try again later.", MB_OK)
    end

    return(nil)
  end

end
