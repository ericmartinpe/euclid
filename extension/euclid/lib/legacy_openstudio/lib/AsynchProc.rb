# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

module LegacyOpenStudio

  class AsynchProc

    def initialize(delay = 50)
      seconds = (delay/1000).to_i
      UI.start_timer(seconds, false) { yield }
    end

  end

end
