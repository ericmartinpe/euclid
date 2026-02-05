# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")


module LegacyOpenStudio

  class AttachedShadingSurfaceInfoInterface < DialogInterface

    def populate_hash
      @drawing_interface = Plugin.model_manager.selected_drawing_interface

      if (not @drawing_interface.nil?)
        @input_object = @drawing_interface.input_object

        @hash['NAME'] = @input_object.name
        @hash['BASE_SURFACE'] = @input_object.get_property('base_surface_name', '').to_s
        @hash['TRANSMITTANCE'] = @input_object.get_property('transmittance_schedule_name', '').to_s

        # Need better method here
        if (Plugin.model_manager.units_system == "SI")
          i = 0
          area = @drawing_interface.area.to_m.to_m
        else
          i = 1
          area = @drawing_interface.area.to_feet.to_feet
        end

        @hash['AREA'] = area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['VERTICES'] = @input_object.get_property('number_of_vertices', '').to_s
        @hash['OBJECT_TEXT'] = format_object_text(@input_object)
      end

    end


    def report
      input_object_copy = @input_object.copy

      @input_object.set_property('name', @hash['NAME'].strip)

      # Lookup base surface object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("BUILDINGSURFACE:DETAILED")
      if (object = objects.find { |object| object.name == @hash['BASE_SURFACE'] })
        @input_object.set_property('base_surface_name', object.name)
      else
        @input_object.set_property('base_surface_name', @hash['BASE_SURFACE'])
      end

      # Lookup transmittance schedule object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("SCHEDULE:YEAR", "SCHEDULE:COMPACT", "SCHEDULE:FILE")
      if (object = objects.find { |object| object.name == @hash['TRANSMITTANCE'] })
        @input_object.set_property('transmittance_schedule_name', object.name)
      else
        @input_object.set_property('transmittance_schedule_name', @hash['TRANSMITTANCE'])
      end

      # Update object text with changes
      @hash['OBJECT_TEXT'] = format_object_text(@input_object)

      populate_hash

      # Update drawing interface
      @drawing_interface.on_change_input_object

      if (@input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      return(true)
    end

  end

end
