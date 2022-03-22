# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/Dialogs")

module LegacyOpenStudio

  # A class to hold the definitions for spaces (new to EnergyPlus v9.6)
  class SpaceManager

    def initialize

    end

    def new_space_stub

      # Populate zone name list
      zone_names = Plugin.model_manager.input_file.find_objects_by_class_name("ZONE").collect { |zone| zone.name }.sort

      # Build string with vertical pipes between zone names to populate menu drop-down
      zone_names_string = ''
      for name in zone_names
        if zone_names.find_index(name) == zone_names.length() - 1 # if last zone name, don't add vertical pipe
          zone_names_string += name
        else
          zone_names_string += "#{name}|"
        end
      end

      if (results = UI.inputbox(['Enter name for new Space:  ', 'Select Zone for new Space: '], ['', ''], ['', zone_names_string], 'Add New Space Stub'))
        if (results[0].empty?)
          UI.messagebox("You must enter a name to create a new space.\nNo object was created.")
        else
          if (results[1].empty?) or (not zone_names.include?(results[1])) # check that user didn't type in new zone name that's not in model
            UI.messagebox("You must select an existing Zone name to assign the new space to.\nNo space object was created.")
          else
            name = results[0]
            zone_name = results[1]

            # Lookup existing space objects
            spaces = Plugin.model_manager.input_file.find_objects_by_class_name("SPACE")

            if (spaces.find { |space| space.name == name })
              UI.messagebox('The name "' + name + '" is already in use by another space object.' + "\nNo object was created.")
            else
              input_object = InputObject.new("Space")
              input_object.name = name
              input_object.fields[2] = zone_name

              Plugin.model_manager.input_file.add_object(input_object)

              UI.messagebox("The new space object was successfully created for #{zone_name}!\nDon't forget to edit the input file outside of SketchUp to define the reporting inputs (space type, tag) of the space.")
            end
          end
        end
      end

    end

  end

end
