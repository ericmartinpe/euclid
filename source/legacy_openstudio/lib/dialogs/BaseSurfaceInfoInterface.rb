# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")


module LegacyOpenStudio

  class BaseSurfaceInfoInterface < DialogInterface

    def populate_hash

      @drawing_interface = Plugin.model_manager.selected_drawing_interface

      if (not @drawing_interface.nil?)
        @input_object = @drawing_interface.input_object

        @hash['NAME'] = @input_object.name
        @hash['TYPE'] = @input_object.get_property('surface_type', '').upcase
        @hash['CONSTRUCTION'] = @input_object.get_property('construction_name', '').to_s
        @hash['ZONE'] = @input_object.get_property('zone_name', '').to_s
        @hash['SPACE'] = @input_object.get_property('space_name', '').to_s
        @hash['OUTSIDE_BOUNDARY_CONDITION'] = @input_object.get_property('outside_boundary_condition', '').upcase
        @hash['OUTSIDE_BOUNDARY_OBJECT'] = @input_object.get_property('outside_boundary_condition_object', '').to_s

        @hash['SUN'] = (@input_object.get_property('sun_exposure', '').upcase == "SUNEXPOSED")
        @hash['WIND'] = (@input_object.get_property('wind_exposure', '').upcase == "WINDEXPOSED")

        @hash['VIEW_FACTOR_TO_GROUND'] = @input_object.get_property('view_factor_to_ground', '')


        # Need better method here
        if (Plugin.model_manager.units_system == "SI")
          i = 0
          gross_area = @drawing_interface.gross_area.to_m.to_m
          net_area = @drawing_interface.net_area.to_m.to_m
        else
          i = 1
          gross_area = @drawing_interface.gross_area.to_feet.to_feet
          net_area = @drawing_interface.net_area.to_feet.to_feet
        end

        @hash['AREA'] = gross_area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['NET_AREA'] = net_area.round_to(Plugin.model_manager.length_precision).to_s + " " + Plugin.model_manager.units_hash['m2'][i]
        @hash['VERTICES'] = @input_object.get_property('number_of_vertices', '').to_s
        @hash['SUB_SURFACES'] = @drawing_interface.sub_surface_count
        @hash['PERCENT_GLAZING'] = @drawing_interface.percent_glazing.round_to(1).to_s + " %"
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

      # Lookup Zone object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("ZONE")
      if (object = objects.find { |object| object.name == @hash['ZONE'] })
        @input_object.set_property('zone_name', object.name)
      else
        @input_object.set_property('zone_name', @hash['ZONE'])
      end

      # Lookup Space object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("SPACE")
      if (object = objects.find { |object| object.name == @hash['SPACE'] })
        @input_object.set_property('space_name', object.name)
      else
        @input_object.set_property('space_name', @hash['SPACE'])
      end
      
      @input_object.set_property('outside_boundary_condition', @hash['OUTSIDE_BOUNDARY_CONDITION'])

      case (@hash['OUTSIDE_BOUNDARY_CONDITION'])

      when "OUTDOORS"
        # Set some things to blank

      when "GROUND"

      when "GROUNDFCFACTORMETHOD"

      when "GROUNDSLABPREPROCESSORAVERAGE"

      when "GROUNDSLABPREPROCESSORCORE"

      when "GROUNDSLABPREPROCESSORPERIMETER"

      when "GROUNDBASEMENTPREPROCESSORAVERAGEWALL"

      when "GROUNDBASEMENTPREPROCESSORAVERAGEFLOOR"

      when "GROUNDBASEMENTPREPROCESSORUPPERWALL"

      when "GROUNDBASEMENTPREPROCESSORLOWERWALL"

      when "SURFACE"
        outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("BUILDINGSURFACE:DETAILED", @hash['OUTSIDE_BOUNDARY_OBJECT'])

      when "ZONE"
        outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("ZONE", @hash['OUTSIDE_BOUNDARY_OBJECT'])

      when "FOUNDATION"
        outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("FOUNDATION:KIVA", @hash['OUTSIDE_BOUNDARY_OBJECT'])

      when "OTHERSIDECOEFFICIENTS"
        outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("SURFACEPROPERTY:OTHERSIDECOEFFICIENTS", @hash['OUTSIDE_BOUNDARY_OBJECT'])

      when "OTHERSIDECONDITIONSMODEL"
        outside_boundary_object = Plugin.model_manager.input_file.find_object_by_class_and_name("SURFACEPROPERTY:OTHERSIDECONDITIONSMODEL", @hash['OUTSIDE_BOUNDARY_OBJECT'])

      end

      if (outside_boundary_object.nil?)
        @input_object.set_property('outside_boundary_condition_object', '')
      else
        @input_object.set_property('outside_boundary_condition_object', outside_boundary_object.name)
      end


      if (@hash['SUN'])
        @input_object.set_property('sun_exposure', 'SunExposed')
      else
        @input_object.set_property('sun_exposure', 'NoSun')
      end

      if (@hash['WIND'])
        @input_object.set_property('wind_exposure', 'WindExposed')
      else
        @input_object.set_property('wind_exposure', 'NoWind')
      end


      @input_object.set_property('view_factor_to_ground', @hash['VIEW_FACTOR_TO_GROUND'].strip)


      # Update object text with changes
      @hash['OBJECT_TEXT'] = @input_object.to_idf

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
