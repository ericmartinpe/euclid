# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")
require("euclid/lib/legacy_openstudio/lib/inputfile/InputObjectAdapter")


module LegacyOpenStudio

  class SubSurfaceInfoInterface < DialogInterface

    def populate_hash

      @drawing_interface = Plugin.model_manager.selected_drawing_interface

      if (not @drawing_interface.nil?)
        @input_object = @drawing_interface.input_object

        @hash['NAME'] = @input_object.name
        @hash['TYPE'] = @input_object.get_property('surface_type', '').upcase
        @hash['CONSTRUCTION'] = @input_object.get_property('construction_name', '').to_s
        @hash['BASE_SURFACE'] = @input_object.get_property('building_surface_name', '').to_s
        @hash['OUTSIDE_BOUNDARY_OBJECT'] = @input_object.get_property('outside_boundary_condition_object', '').to_s
        @hash['VIEW_FACTOR_TO_GROUND'] = @input_object.get_property('view_factor_to_ground', '')
        # Removed input field for "WINDOWPROPERTY:SHADINGCONTROL" in "FENESTRATIONSURFACE:DETAILED" object for EnergyPlus v9.0
        # @hash['SHADING_DEVICE'] = @input_object.get_property('shading_control_name', '').to_s
        @hash['FRAME_DIVIDER'] = @input_object.get_property('frame_and_divider_name', '').to_s
        @hash['MULTIPLIER'] = @input_object.get_property('multiplier', '')


        # Need better method here
        if (Plugin.model_manager.units_system == "SI")
          i = 0
          unit_area = @drawing_interface.unit_area.to_m.to_m
          total_area = @drawing_interface.area.to_m.to_m
        else
          i = 1
          unit_area = @drawing_interface.unit_area.to_feet.to_feet
          total_area = @drawing_interface.area.to_feet.to_feet
        end

        # Removed input field for "WINDOWPROPERTY:SHADINGCONTROL" in "FENESTRATIONSURFACE:DETAILED" object for EnergyPlus v9.0
        @hash['VERTICES'] = @input_object.get_property('number_of_vertices', '').to_s
        @hash['UNIT_AREA'] = unit_area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['TOTAL_AREA'] = total_area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['OBJECT_TEXT'] = @input_object.to_idf
      end

    end


    def report
      input_object_copy = @input_object.copy

      @input_object.set_property('name', @hash['NAME'].strip)
      @input_object.set_property('surface_type', @hash['TYPE'])

      # Lookup Construction object
      objects = Plugin.model_manager.construction_manager.constructions
      if (object = objects.find { |object| object.name == @hash['CONSTRUCTION'] })
        @input_object.set_property('construction_name', object.name)
      else
        @input_object.set_property('construction_name', @hash['CONSTRUCTION'])
      end

      # Lookup base surface object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("BUILDINGSURFACE:DETAILED")
      if (base_surface = objects.find { |object| object.name == @hash['BASE_SURFACE'] })
        @input_object.set_property('building_surface_name', base_surface.name)
      else
        @input_object.set_property('building_surface_name', @hash['BASE_SURFACE'])
      end

      outside_boundary_object = nil
      if (base_surface)
        boundary_condition = base_surface.get_property('outside_boundary_condition', '').upcase

        case (boundary_condition)

        when "FOUNDATION", "OUTDOORS", "GROUND", "GROUNDFCFACTORMETHOD", "GROUNDSLABPREPROCESSORAVERAGE",
              "GROUNDSLABPREPROCESSORCORE", "GROUNDSLABPREPROCESSORPERIMETER",
              "GROUNDBASEMENTPREPROCESSORAVERAGEWALL", "GROUNDBASEMENTPREPROCESSORAVERAGEFLOOR",
              "GROUNDBASEMENTPREPROCESSORUPPERWALL", "GROUNDBASEMENTPREPROCESSORLOWERWALL"
          # OUTSIDE_BOUNDARY_OBJECT should be blank or disabled

        when "SURFACE"
          outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("FENESTRATIONSURFACE:DETAILED", @hash['OUTSIDE_BOUNDARY_OBJECT'])

        when "OTHERSIDECOEFFICIENTS"
          outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("SURFACEPROPERTY:OTHERSIDECOEFFICIENTS", @hash['OUTSIDE_BOUNDARY_OBJECT'])

        when "ZONE"
          outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("ZONE", @hash['OUTSIDE_BOUNDARY_OBJECT'])

        when "OTHERSIDECONDITIONSMODEL"
          outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("SURFACEPROPERTY:OTHERSIDECONDITIONSMODEL", @hash['OUTSIDE_BOUNDARY_OBJECT'])

        else  # Blank
          # OUTSIDE_BOUNDARY_OBJECT should be blank or disabled
        end
      end

      if (outside_boundary_object.nil?)
        @input_object.set_property('outside_boundary_condition_object', '')
      else
        @input_object.set_property('outside_boundary_condition_object', outside_boundary_object.name)
      end

      @input_object.set_property('view_factor_to_ground', @hash['VIEW_FACTOR_TO_GROUND'].strip)

      # Removed input field for "WINDOWPROPERTY:SHADINGCONTROL" in "FENESTRATIONSURFACE:DETAILED" object for EnergyPlus v9.0
      # if (shading_device = Plugin.model_manager.input_file.find_object_by_class_and_name("WINDOWPROPERTY:SHADINGCONTROL", @hash['SHADING_DEVICE']))
      #   @input_object.set_property('shading_control_name', shading_device.name)
      # else
      #   @input_object.set_property('shading_control_name', @hash['SHADING_DEVICE'])
      # end

      if (frame_divider = Plugin.model_manager.input_file.find_object_by_class_and_name("WINDOWPROPERTY:FRAMEANDDIVIDER", @hash['FRAME_DIVIDER']))
        @input_object.set_property('frame_and_divider_name', frame_divider.name)
      else
        @input_object.set_property('frame_and_divider_name', @hash['FRAME_DIVIDER'])
      end

      @input_object.set_property('multiplier', @hash['MULTIPLIER'].strip)
      # Possibly warn if > 1 and using Full Interior solar distribution

      # Update object text with changes
      @hash['OBJECT_TEXT'] = @input_object.to_idf

      # Update object summary because multiplier could change
      populate_hash

      # Update drawing interface
      @drawing_interface.on_change_input_object

      if (@input_object != input_object_copy)
        Plugin.model_manager.input_file.modified = true
      end

      return(true)  # No validation is being done right now
    end

  end

end
