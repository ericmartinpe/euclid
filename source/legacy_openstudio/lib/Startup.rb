# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.


# This script simply loads the rest of the plugin

#$debug = true


# check the Ruby version, if necessary.  So far the included Ruby interpreter works fine for everything.
# if (RUBY_VERSION < '1.8.0')


if (RUBY_PLATFORM =~ /mswin/ || RUBY_PLATFORM =~ /mingw/)  # Windows
  minimum_version = '8.0.0000'
  minimum_version_key = '0008000000000'
elsif (RUBY_PLATFORM =~ /darwin/)  # Mac OS X
  minimum_version = '8.0.0000'
  minimum_version_key = '0008000000000'
end

installed_version = Sketchup.version
installed_version_key = ''; installed_version.split('.').each { |e| installed_version_key += e.rjust(4, '0') }

if (installed_version_key < minimum_version_key)
  UI.messagebox("#{EUCLID_EXTENSION_NAME} is only compatible with SketchUp version " + minimum_version +
    " or higher.\nThe installed version is " + installed_version + ". The plugin was not loaded.", MB_OK)
else
  # start legacy plugin after everything and check for OpenStudio or Legacy OpenStudio already loaded
  timer_id = UI.start_timer(2, false) {
    # This seems to be the only reliable way to check if OpenStudio is loaded.
    # Sketchup.extensions["OpenStudio"].loaded? doesn't register as true until the extension is completely loaded, and OpenStudio takes so long to load.
    if (Kernel.const_defined?(:OpenStudio) and OpenStudio.const_defined?(:PluginManager))
      UI.messagebox("Unable to load the #{EUCLID_EXTENSION_NAME} extension.\n\nThe OpenStudio extension is already loaded. Disable OpenStudio using Extension Manager before using the #{EUCLID_EXTENSION_NAME} extension.", MB_OK)
    elsif (Kernel.const_defined?(:LegacyOpenStudio) and LegacyOpenStudio.const_defined?(:PluginManager))
      UI.messagebox("Unable to load the #{EUCLID_EXTENSION_NAME} extension.\n\nThe Legacy OpenStudio extension is already loaded. Disable Legacy OpenStudio using Extension Manager before using the #{EUCLID_EXTENSION_NAME} extension.", MB_OK)
    else
      load("euclid/lib/legacy_openstudio/lib/PluginManager.rb")
    end
  }

  # NOTE: There is a SketchUp bug that if you open a modal window in a non-repeating timer the timer will repeat until the window is closed.
  # Force the timer to stop after a safe time period--but before the timer repeats a second time.
  UI.start_timer(3, false) { UI.stop_timer(timer_id) }
end

