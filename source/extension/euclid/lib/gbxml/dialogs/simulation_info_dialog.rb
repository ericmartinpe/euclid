# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/Dialogs")
require("euclid/lib/legacy_openstudio/lib/dialogs/DialogContainers")


module Euclid
  module GbXML

    class SimulationInfoDialog < LegacyOpenStudio::PropertiesDialog

      GEOLOCATION_CLEAR = 24197
      GEOLOCATION_SHOW = 24216


      def initialize(container, interface, hash)
        super
        w = LegacyOpenStudio::Plugin.platform_select(400, 430)
        h = LegacyOpenStudio::Plugin.platform_select(400, 445)
        @container = LegacyOpenStudio::WindowContainer.new("Location Info", w, h, 150, 150)
        @container.set_file(LegacyOpenStudio::Plugin.dir + "/../gbxml/dialogs/html/simulation-info.html")
        add_callbacks
      end


      def add_callbacks
        super
        @container.web_dialog.add_action_callback("on_map") { on_map }
      end


      def on_change_element(d, p)
        super
        report
      end


      def on_map
        Sketchup.send_action(GEOLOCATION_CLEAR)
        Sketchup.send_action(GEOLOCATION_SHOW)

        # on Mac: Sketchup.send_action "showGeoLocation:"
        #         Sketchup.send_action "clearLocation:"
      end

    end

  end
end
