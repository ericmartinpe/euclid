# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

minimum_version = "15.3"

if (Gem::Version.new(Sketchup.version) > Gem::Version.new("17.0"))
  extensions_ui = "Extension Manager"
else
  extensions_ui = "Preferences/Extensions"
end

if (Gem::Version.new(Sketchup.version) < Gem::Version.new(minimum_version))
  UI.messagebox("Euclid is only compatible with SketchUp version #{minimum_version} or higher.\n" +
    "The installed version is #{Sketchup.version}. The extension was not loaded.", MB_OK)

else
  timer_id = UI.start_timer(2, false) {
    # This seems to be the only reliable way to check if OpenStudio is loaded.
    # Sketchup.extensions["OpenStudio"].loaded? doesn't register as true until the extension is completely loaded, and OpenStudio takes so long to load.
    if (Kernel.const_defined?(:OpenStudio) and OpenStudio.const_defined?(:PluginManager))
      UI.messagebox("Unable to load the Euclid extension.\n\nThe OpenStudio extension is already loaded. Disable OpenStudio using #{extensions_ui} before using the Euclid extension.", MB_OK)
    elsif (Kernel.const_defined?(:LegacyOpenStudio) and LegacyOpenStudio.const_defined?(:PluginManager))
      UI.messagebox("Unable to load the Euclid extension.\n\nThe Legacy OpenStudio extension is already loaded. Disable Legacy OpenStudio using #{extensions_ui} before using the Euclid extension.", MB_OK)
    else

      # Windows encodes this path as Windows-1252. The other directory paths are UTF-8.
      # This causes compatibility errors if a user home directory has special characters in the user name.
      gem_path = ENV['GEM_PATH'].encode("UTF-8")

      if (RUBY_PLATFORM =~ /mswin|msys|mingw|cygwin|bccwin|wince|emc/)  # Windows
        gem_path_delimiter = ";"
      elsif (RUBY_PLATFORM =~ /darwin|mac os/)  # Mac
        gem_path_delimiter = ":"
      end

      # Enable SketchUp to search in additional directories for Ruby gems required by this extension.
      lib_gems = File.expand_path("#{__dir__}/lib/rubygems")
      vendor_gems = File.expand_path("#{__dir__}/vendor/rubygems")

      ENV['GEM_PATH'] = [gem_path, lib_gems, vendor_gems].join(gem_path_delimiter)

      require("euclid/lib/legacy_openstudio/lib/PluginManager")
    end
  }

  # NOTE: There is a SketchUp bug that if you open a modal window in a non-repeating timer the timer will repeat until the window is closed.
  # Force the timer to stop after a safe time period--but before the timer repeats a second time.
  UI.start_timer(3, false) { UI.stop_timer(timer_id) }
end
