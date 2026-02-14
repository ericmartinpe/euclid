# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.


module LegacyOpenStudio

  # Abstract supercalls for all dialog interfaces
  # Everything in an interface is supposed to be independent of the GUI implementation.
  # The only link to the GUI is the call to the 'new' method of the GUI Dialog class.
  class DialogInterface

    attr_accessor :dialog, :hash


    def initialize(container = nil)
      @hash = Hash.new
      populate_hash

      # This is where subclasses will create the Dialog object.
      # @dialog = Dialog.new(self, @hash)
    end


    def populate_hash
      # Update hash values with data from the EnergyPlus object.
      # This method can be called externally when the EnergyPlus object changes.
      # Note:  Hash keys, e.g., 'name', are case sensitive!
      # @hash['key1'] = value1
      # @hash['key2'] = value2
    end


    def update
      populate_hash
      #show
      @dialog.update
    end


    def update_units
      @dialog.update_units
    end


    def show
      @dialog.show
      #update  # don't need this...causes double updates which is slow
    end


    def report
      # Report data from hash values back to the EnergyPlus object.
      # This method is called by the dialog when changes are finalized (usually on 'OK' or 'Apply')
      # Note:  Hash keys, e.g., 'name', are case sensitive!
      # value1 = @hash['key1']
      # value2 = @hash['key2']

      # Return value validates the user input and allows the dialog to close.
      # A false value can force the user to fix their input before closing is allowed.
      return(true)
    end


    def format_object_text(input_object)
      text = "#{input_object.class_name},\n"
      text += "  #{input_object.name};\n\n"
      
      # Add basic properties
      text += "Surface Type: #{input_object.get_property('surface_type', '')}\n"
      text += "Construction: #{input_object.get_property('construction_name', '')}\n"
      text += "Zone: #{input_object.get_property('zone_name', '')}\n"
      text += "Outside Boundary: #{input_object.get_property('outside_boundary_condition', '')}\n"
      
      # Add vertices
      vertices = input_object.get_property('vertices', [])
      if vertices && vertices.is_a?(Array) && !vertices.empty?
        text += "\nVertices (#{vertices.length}):\n"
        vertices.each_with_index do |vertex, i|
          x = vertex['vertex_x_coordinate'] || 0
          y = vertex['vertex_y_coordinate'] || 0
          z = vertex['vertex_z_coordinate'] || 0
          text += "  #{i+1}: (#{x}, #{y}, #{z})\n"
        end
      end
      
      text
    end


    def close
      @dialog.close
    end


    def delete
      Plugin.dialog_manager.remove(self)
    end


    def inspect
      return(self)
    end

  end

end
