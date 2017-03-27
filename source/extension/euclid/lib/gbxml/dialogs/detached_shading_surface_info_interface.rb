# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")


module Euclid
  module GbXML

    class DetachedShadingSurfaceInfoInterface < LegacyOpenStudio::DialogInterface

      def populate_hash

        @drawing_interface = LegacyOpenStudio::Plugin.model_manager.selected_drawing_interface

        if (not @drawing_interface.nil?)
          @input_object = @drawing_interface.input_object

          @hash['DETACHED_SHADING_CLASS'] = @input_object.type
          @hash['NAME'] = @input_object.name

          # Need better method here
          if (LegacyOpenStudio::Plugin.model_manager.units_system == "SI")
            i = 0
            area = @drawing_interface.area.to_m.to_m
          else
            i = 1
            area = @drawing_interface.area.to_feet.to_feet
          end

          @hash['AREA'] = area.round_to(LegacyOpenStudio::Plugin.model_manager.length_precision).to_s + " " + LegacyOpenStudio::Plugin.model_manager.units_hash['m2'][i]
          @hash['VERTICES'] = @input_object.polygon.points.length.to_s
          @hash['OBJECT_TEXT'] = @input_object.mediator.conjugate_object.to_xml
        end

      end


      def report
        input_object_copy = @input_object.copy

        @input_object.name = @hash['NAME'].strip

        # Update object text with changes
        @hash['OBJECT_TEXT'] = @input_object.mediator.conjugate_object.to_xml

        populate_hash

        # Update drawing interface
        @drawing_interface.on_change_input_object

        if (@input_object != input_object_copy)
          LegacyOpenStudio::Plugin.model_manager.input_file.modified = true
        end

        return(true)
      end

    end

  end
end
