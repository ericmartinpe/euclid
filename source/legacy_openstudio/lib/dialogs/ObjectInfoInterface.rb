# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")

require("euclid/lib/legacy_openstudio/lib/dialogs/BuildingInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/ZoneInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/BaseSurfaceInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/SubSurfaceInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/AttachedShadingSurfaceInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/DetachedShadingGroupInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/DetachedShadingSurfaceInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/OutputIlluminanceMapInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/DaylightingControlsInfoInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/NoSelectionInfoInterface")

require("euclid/lib/legacy_openstudio/lib/dialogs/ObjectInfoDialog")

require("euclid/lib/gbxml/dialogs/detached_shading_group_info_interface")
require("euclid/lib/gbxml/dialogs/detached_shading_surface_info_interface")


module LegacyOpenStudio

  class ObjectInfoInterface < DialogInterface

    def initialize(container = nil)
      super
      @dialog = ObjectInfoDialog.new(nil, self, @hash)
    end


    def populate_hash
      case (drawing_interface_class_name = Plugin.model_manager.selected_drawing_interface.class.to_s)

      when "LegacyOpenStudio::Building"
        @active_interface = BuildingInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::Zone"
        @active_interface = ZoneInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::BaseSurface"
        @active_interface = BaseSurfaceInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::SubSurface"
        @active_interface = SubSurfaceInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::AttachedShadingSurface"
        @active_interface = AttachedShadingSurfaceInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::DetachedShadingGroup"
        @active_interface = DetachedShadingGroupInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::DetachedShadingSurface"
        @active_interface = DetachedShadingSurfaceInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::OutputIlluminanceMap"
        @active_interface = OutputIlluminanceMapInfoInterface.new
        @hash = @active_interface.hash

      when "LegacyOpenStudio::DaylightingControls"
        @active_interface = DaylightingControlsInfoInterface.new
        @hash = @active_interface.hash

      when "Euclid::GbXML::DetachedShadingGroupInterface"
        @active_interface = Euclid::GbXML::DetachedShadingGroupInfoInterface.new
        @hash = @active_interface.hash

      when "Euclid::GbXML::DetachedShadingSurfaceInterface"
        @active_interface = Euclid::GbXML::DetachedShadingSurfaceInfoInterface.new
        @hash = @active_interface.hash

      else  # NilClass
        @active_interface = NoSelectionInfoInterface.new
        @hash = Hash.new
        @hash['OBJECT_TEXT'] = ""

      end

      @hash['CLASS'] = drawing_interface_class_name  # This is how the Dialog knows what its working with
    end


    def report
      if (@active_interface.report)
        @dialog.update
        return(true)
      else
        return(false)
      end
    end

  end

end
