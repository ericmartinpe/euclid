# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

module LegacyOpenStudio

  class AsynchProc

    attr_reader :timer_id


    def initialize(delay = 50)
      seconds = (delay/1000).to_i
      @timer_id = UI.start_timer(seconds, false) { yield }
    end

  end

end
