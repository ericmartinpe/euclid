# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")


module Euclid
  module GbXML

    class DetachedShadingGroupInfoInterface < LegacyOpenStudio::DialogInterface

      def populate_hash

        @drawing_interface = LegacyOpenStudio::Plugin.model_manager.selected_drawing_interface

        if (not @drawing_interface.nil?)
          @hash['TYPE'] = @drawing_interface.surface_type

          # Need better method here
          if (LegacyOpenStudio::Plugin.model_manager.units_system == "SI")
            i = 0
            surface_area = @drawing_interface.area.to_m.to_m
          else
            i = 1
            surface_area = @drawing_interface.area.to_feet.to_feet
          end

          @hash['SURFACES'] = @drawing_interface.children.count
          @hash['SURFACE_AREA'] = surface_area.round_to(LegacyOpenStudio::Plugin.model_manager.length_precision).to_s + " " + LegacyOpenStudio::Plugin.model_manager.units_hash['m2'][i]

          @hash['OBJECT_TEXT'] = ""
        end

      end


      def report
        surface_type_copy = @drawing_interface.surface_type.dup

        @drawing_interface.surface_type = @hash['TYPE']

        # Update drawing interface
        #@drawing_interface.on_change_input_object  # Causes problems with "Counterclockwise:  Fix unintended reversed face"; something with comparing polygon before coordinates have been updated

        # Kind of a kludge: see above
        @drawing_interface.paint_entity
        @drawing_interface.update_input_object

        if (@drawing_interface.surface_type != surface_type_copy)
          LegacyOpenStudio::Plugin.model_manager.input_file.modified = true
        end

        return(true)
      end

    end

  end
end
