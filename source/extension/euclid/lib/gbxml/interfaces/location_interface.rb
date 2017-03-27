# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")
require("euclid/lib/legacy_openstudio/lib/observers/ShadowInfoObserver")


module Euclid
  module GbXML

    class LocationInterface < LegacyOpenStudio::DrawingInterface

      def create_input_object
        super
      end


      # Updates the input object with the current state of the entity.
      def update_input_object
        super

        if (valid_entity?)
          @input_object.name = @entity["City"]
          @input_object.latitude = @entity["Latitude"]
          @input_object.longitude = @entity["Longitude"]
          @input_object.time_zone_offset = @entity["TZOffset"]
        end
      end


      def parent_from_input_object
        return(LegacyOpenStudio::Plugin.model_manager.model_interface)
      end


      # Location is unlike other drawing interface because it does not actually create the entity.
      # Instead it gets the current ShadowInfo object.
      def create_entity
        @entity = Sketchup.active_model.shadow_info
      end


      def check_entity
        return(false)
      end


      # Updates the entity with the current state of the input object.
      def update_entity
        if (valid_entity?)
          @entity["City"] = @input_object.name
          @entity["Latitude"] = @input_object.latitude
          @entity["Longitude"] = @input_object.longitude
          @entity["TZOffset"] = @input_object.time_zone_offset
        end
      end


      def on_change_entity
        update_input_object
        LegacyOpenStudio::Plugin.dialog_manager.update(Euclid::GbXML::SimulationInfoInterface)
      end


      def parent_from_entity
        return(LegacyOpenStudio::Plugin.model_manager.model_interface)
      end


      def add_observers
        if (valid_entity?)
          @observer = LegacyOpenStudio::ShadowInfoObserver.new(self)
          @entity.add_observer(@observer)
        end
      end
    end

  end
end
