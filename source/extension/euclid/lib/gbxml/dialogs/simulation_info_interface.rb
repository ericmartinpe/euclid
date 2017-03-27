# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")
require("euclid/lib/gbxml/dialogs/simulation_info_dialog")


module Euclid
  module GbXML

    class SimulationInfoInterface < LegacyOpenStudio::DialogInterface

      def initialize
        super
        @dialog = SimulationInfoDialog.new(nil, self, @hash)
      end


      def populate_hash
        input_object = LegacyOpenStudio::Plugin.model_manager.location.input_object
        if (input_object)
          @hash['LOCATION_NAME'] = input_object.name
          @hash['LATITUDE'] = input_object.latitude
          @hash['LONGITUDE'] = input_object.longitude
          @hash['TIME_ZONE_OFFSET'] = input_object.time_zone_offset
          @hash['ELEVATION'] = input_object.elevation  # Not properly converted to local units--always assumes feet
          @hash['AZIMUTH'] = input_object.azimuth
        else
          puts "This file has no location."
        end
      end


#      def update
#        puts "*update"
#        super
        #populate_hash
        #@dialog.update
#      end


      def report
        # Must handle SurfaceGeometry first because changing Location will trigger the ShadowInfoObserver which, in turn, updates this interface.

        # Report Location input object
        input_object = LegacyOpenStudio::Plugin.model_manager.location.input_object
        input_object_copy = input_object.copy

        input_object.name = @hash['LOCATION_NAME']
        input_object.latitude = @hash['LATITUDE'].to_f
        input_object.longitude = @hash['LONGITUDE'].to_f
        input_object.time_zone_offset = @hash['TIME_ZONE_OFFSET'].to_i
        input_object.elevation = @hash['ELEVATION'].to_f
        input_object.azimuth = @hash['AZIMUTH'].to_f

        # Update drawing interface
        LegacyOpenStudio::Plugin.model_manager.location.on_change_input_object

        if (input_object != input_object_copy)
          LegacyOpenStudio::Plugin.model_manager.input_file.modified = true

          if (input_object.azimuth != input_object_copy.azimuth)
            # Update any input objects that depend on azimuth.
            LegacyOpenStudio::Plugin.model_manager.model_interface.children.collect { |interface|
              if (interface.valid_entity? and interface.class == DetachedShadingGroupInterface and
                (interface.surface_type == BEMkit::Shading::TYPE_BUILDING_SHADE or interface.surface_type == BEMkit::Shading::TYPE_BUILDING_PHOTOVOLTAIC))

                interface.update_input_object
              end
            }
            LegacyOpenStudio::Plugin.dialog_manager.update(LegacyOpenStudio::ObjectInfoInterface)
          end

          # Does not appear to be needed:
          #LegacyOpenStudio::Plugin.dialog_manager.update(SimulationInfoInterface)
        end

        return(true)
      end

    end

  end
end
