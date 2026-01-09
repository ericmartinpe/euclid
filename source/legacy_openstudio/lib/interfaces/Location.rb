# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/interfaces/DrawingInterface")
require("euclid/lib/legacy_openstudio/lib/inputfile/InputObjectAdapter")
require("euclid/lib/legacy_openstudio/lib/observers/ShadowInfoObserver")


module LegacyOpenStudio

  class Location < DrawingInterface

    def create_input_object
      @input_object = InputObject.new("SITE:LOCATION")
      @input_object.fields[1] = Plugin.model_manager.input_file.new_unique_object_name
      @input_object.fields[2] = "0.0"
      @input_object.fields[3] = "0.0"
      @input_object.fields[4] = "0.0"
      @input_object.fields[5] = "0.0"

      super
    end


    # Updates the input object with the current state of the entity.
    def update_input_object
      super

      if (valid_entity?)
        adapter.set_field(1, @entity["City"])
        adapter.set_field(2, @entity["Latitude"].to_s)
        adapter.set_field(3, @entity["Longitude"].to_s)
        adapter.set_field(4, @entity["TZOffset"].to_s)
        #adapter.set_field(5, ?)  # Elevation is not handled by shadow info
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

    # Adapter for unified IDF/epJSON access
    def adapter
      @adapter ||= InputObjectAdapter.new(@input_object)
    end

    # Updates the entity with the current state of the input object.
    def update_entity
      if (valid_entity?)
        @entity["City"] = adapter.get_field(1)
        @entity["Latitude"] = adapter.get_field(2).to_f
        @entity["Longitude"] = adapter.get_field(3).to_f
        @entity["TZOffset"] = adapter.get_field(4).to_f
        # ? = adapter.get_field(5).to_f   Elevation is not handled by shadow info
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
