# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/DefaultConstructionsDialog")


module LegacyOpenStudio

  class DefaultConstructionsInterface < DialogInterface

    def initialize
      super
      @dialog = DefaultConstructionsDialog.new(nil, self, @hash)
    end

  end

end
