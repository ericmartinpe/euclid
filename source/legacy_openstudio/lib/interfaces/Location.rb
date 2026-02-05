# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")
require("euclid/lib/legacy_openstudio/lib/observers/ShadowInfoObserver")


module LegacyOpenStudio

  class Location < DrawingInterface

    def create_input_object
      @input_object = JsonInputObject.new("Site:Location", Plugin.model_manager.input_file.new_unique_object_name, {
        "latitude" => 0.0,
        "longitude" => 0.0,
        "time_zone" => 0.0,
        "elevation" => 0.0
      })

      super
    end


    # Updates the input object with the current state of the entity.
    def update_input_object
      super

      if (valid_entity?)
        @input_object.set_property('latitude', @entity["Latitude"].to_s)
        @input_object.set_property('longitude', @entity["Longitude"].to_s)
        @input_object.set_property('time_zone', @entity["TZOffset"].to_s)
        # @input_object.set_property('elevation', ?)  # Elevation is not handled by shadow info
      end
    end


    def parent_from_input_object
      return(Plugin.model_manager.model_interface)
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
        @entity["Latitude"] = @input_object.get_property('latitude', 0).to_f
        @entity["Longitude"] = @input_object.get_property('longitude', 0).to_f
        @entity["TZOffset"] = @input_object.get_property('time_zone', 0).to_f
        # ? = @input_object.get_property('elevation', 0).to_f   Elevation is not handled by shadow info
      end
    end


    def on_change_entity
      update_input_object
      Plugin.dialog_manager.update(SimulationInfoInterface)
    end


    def parent_from_entity
      return(Plugin.model_manager.model_interface)
    end


    def add_observers
      if (valid_entity?)
        @observer = ShadowInfoObserver.new(self)
        @entity.add_observer(@observer)
      end
    end
  end


end
