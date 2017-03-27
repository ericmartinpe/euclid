# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/Dialogs")


module Euclid
  module GbXML

    class DetachedShadingSurfaceInfoPage < LegacyOpenStudio::Page

      def add_callbacks
        super
        @container.web_dialog.add_action_callback("on_change_element") { |d, p| on_change_element(d, p) }
      end


      def on_load

        # Don't set the background color because it causes the dialog to flash.
        #@container.execute_function("setBackgroundColor('" + default_dialog_color + "')")
        update_units
        update
      end


      def on_change_element(d, p)
        super
        report
      end

    end

  end
end
