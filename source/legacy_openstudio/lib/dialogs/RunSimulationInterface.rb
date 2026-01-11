# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("euclid/lib/legacy_openstudio/lib/dialogs/DialogInterface")
require("euclid/lib/legacy_openstudio/lib/dialogs/RunSimulationDialog")
require("tmpdir")


module LegacyOpenStudio

  class RunSimulationInterface < DialogInterface

    def initialize
      super
      @dialog = RunSimulationDialog.new(nil, self, @hash)
    end

    def populate_hash
      # Read the SimulationControl object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("SimulationControl")
      if (objects.empty?)
        @hash['RUN_DESIGN_DAYS'] = true
        @hash['RUN_WEATHER_FILE'] = true
        @hash['DO_HVAC_SIZING'] = false
        @hash['MAX_HVAC_SIZING_PASSES'] = "1"
      else
        sim_control = objects.to_a.first
        
        run_design_days = sim_control.get_property('run_simulation_for_sizing_periods', 'Yes')
        if (run_design_days.to_s.upcase == "YES")
          @hash['RUN_DESIGN_DAYS'] = true
        else
          @hash['RUN_DESIGN_DAYS'] = false
        end

        run_weather = sim_control.get_property('run_simulation_for_weather_file_run_periods', 'Yes')
        if (run_weather.to_s.upcase == "YES")
          @hash['RUN_WEATHER_FILE'] = true
        else
          @hash['RUN_WEATHER_FILE'] = false
        end

        do_hvac = sim_control.get_property('do_hvac_sizing_simulation_for_sizing_periods', 'No')
        if (do_hvac.to_s.upcase == "YES")
          @hash['DO_HVAC_SIZING'] = true
        else
          @hash['DO_HVAC_SIZING'] = false
        end

        max_passes = sim_control.get_property('maximum_number_of_hvac_sizing_simulation_passes', '1')
        @hash['MAX_HVAC_SIZING_PASSES'] = max_passes.to_s
      end

      @hash['RUN_DIR'] = Dir.tmpdir + "/OpenStudio/run"
      @hash['EPW_PATH'] = Plugin.model_manager.get_attribute("Weather File Path")

      # Read the RUNPERIOD object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("RunPeriod")
      if (objects.empty?)
        @hash['ANNUAL_SIMULATION'] = true
        @hash['RUN_PERIOD_NAME'] = "Simulation" # name of RunPeriod cannot be left blank as of EnergyPlus v9.2
        @hash['START_MONTH'] = "1"
        @hash['START_DATE'] = "1"
        @hash['START_YEAR'] = ""
        @hash['END_MONTH'] = "12"
        @hash['END_DATE'] = "31"
        @hash['END_YEAR'] = ""
        @hash['START_DAY'] = "Sunday"
      else
        run_period = objects.to_a.first
        # Only can handle the first run period currently; multiple run periods are actually allowed in EnergyPlus.

        # Check if loaded RunPeriod object has name - cannot be left blank as of EnergyPlus v9.2
        period_name = run_period.name
        if (period_name.to_s.empty?)
          UI.messagebox("RunPeriod object has no name, yet this is a required input field.\nSetting RunPeriod object name to 'Simulation'.")
          @hash['RUN_PERIOD_NAME'] = "Simulation" # name of RunPeriod
        else
          @hash['RUN_PERIOD_NAME'] = period_name.to_s
        end
        
        @hash['START_MONTH'] = run_period.get_property('begin_month', '1').to_s
        @hash['START_DATE'] = run_period.get_property('begin_day_of_month', '1').to_s
        @hash['START_YEAR'] = run_period.get_property('begin_year', '').to_s
        @hash['END_MONTH'] = run_period.get_property('end_month', '12').to_s
        @hash['END_DATE'] = run_period.get_property('end_day_of_month', '31').to_s
        @hash['END_YEAR'] = run_period.get_property('end_year', '').to_s
        
        # Keep proper case for epJSON (e.g., "Sunday" not "SUNDAY")
        start_day = run_period.get_property('day_of_week_for_start_day', 'Sunday').to_s
        @hash['START_DAY'] = start_day

        if (@hash['START_MONTH'] == "1" and @hash['START_DATE'] == "1" and @hash['END_MONTH'] == "12" and @hash['END_DATE'] == "31")
          @hash['ANNUAL_SIMULATION'] = true
        else
          @hash['ANNUAL_SIMULATION'] = false
        end
      end

      @hash['REPORT_ABUPS'] = Plugin.model_manager.get_attribute("Report ABUPS")
      @hash['ABUPS_FORMAT'] = Plugin.model_manager.get_attribute("ABUPS Format")
      @hash['ABUPS_UNITS'] = Plugin.model_manager.get_attribute("ABUPS Units")
      @hash['REPORT_DXF'] = Plugin.model_manager.get_attribute("Report DXF")
      @hash['REPORT_SQL'] = Plugin.model_manager.get_attribute("Report Sql")
      @hash['REPORT_ZONE_TEMPS'] = Plugin.model_manager.get_attribute("Report Zone Temps")
      @hash['REPORT_SURF_TEMPS'] = Plugin.model_manager.get_attribute("Report Surface Temps")
      @hash['REPORT_DAYLIGHTING'] = Plugin.model_manager.get_attribute("Report Daylighting")
      @hash['REPORT_ZONE_LOADS'] = Plugin.model_manager.get_attribute("Report Zone Loads")
      @hash['REPORT_USER_VARS'] = Plugin.model_manager.get_attribute("Report User Variables")

      @hash['CLOSE_SHELL'] = Plugin.model_manager.get_attribute("Close Shell")
      @hash['SHOW_ERR'] = Plugin.model_manager.get_attribute("Show ERR")
      @hash['SHOW_ABUPS'] = Plugin.model_manager.get_attribute("Show ABUPS")
      @hash['SHOW_CSV'] = Plugin.model_manager.get_attribute("Show CSV")

      if (Plugin.platform == Platform_Mac)
        # Automatic close shell feature doesn't work on Mac yet.
        @hash['CLOSE_SHELL'] = false
      end
    end


    def show
      if (Plugin.simulation_manager.busy?)
        Plugin.dialog_manager.remove(self)

        UI.messagebox("EnergyPlus is already running in a shell command window.\n" +
          "To cancel the simulation, close the shell window.")
      else
        super
      end
    end


    def report

      # Save the run settings
      Plugin.model_manager.set_attribute("Weather File Path", @hash['EPW_PATH'])
      Plugin.model_manager.set_attribute("Report ABUPS", @hash['REPORT_ABUPS'])
      Plugin.model_manager.set_attribute("ABUPS Format", @hash['ABUPS_FORMAT'])
      Plugin.model_manager.set_attribute("ABUPS Units", @hash['ABUPS_UNITS'])
      Plugin.model_manager.set_attribute("Report DXF", @hash['REPORT_DXF'])
      Plugin.model_manager.set_attribute("Report Sql", @hash['REPORT_SQL'])
      Plugin.model_manager.set_attribute("Report Zone Temps", @hash['REPORT_ZONE_TEMPS'])
      Plugin.model_manager.set_attribute("Report Surface Temps", @hash['REPORT_SURF_TEMPS'])
      Plugin.model_manager.set_attribute("Report Daylighting", @hash['REPORT_DAYLIGHTING'])
      Plugin.model_manager.set_attribute("Report Zone Loads", @hash['REPORT_ZONE_LOADS'])
      Plugin.model_manager.set_attribute("Report User Variables", @hash['REPORT_USER_VARS'])

      Plugin.model_manager.set_attribute("Close Shell", @hash['CLOSE_SHELL'])
      Plugin.model_manager.set_attribute("Show ERR", @hash['SHOW_ERR'])
      Plugin.model_manager.set_attribute("Show ABUPS", @hash['SHOW_ABUPS'])
      Plugin.model_manager.set_attribute("Show CSV", @hash['SHOW_CSV'])

      # Configure the SimulationControl object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("SimulationControl")
      if (objects.empty?)
        sim_control = JsonInputObject.new("SimulationControl")
        sim_control.set_property('do_zone_sizing_calculation', 'No')
        sim_control.set_property('do_system_sizing_calculation', 'No')
        sim_control.set_property('do_plant_sizing_calculation', 'No')
        Plugin.model_manager.input_file.add_object(sim_control)
      else
        sim_control = objects.to_a.first
      end

      if (@hash['RUN_DESIGN_DAYS'])
        sim_control.set_property('run_simulation_for_sizing_periods', 'Yes')
      else
        sim_control.set_property('run_simulation_for_sizing_periods', 'No')
      end

      if (@hash['RUN_WEATHER_FILE'])
        sim_control.set_property('run_simulation_for_weather_file_run_periods', 'Yes')
      else
        sim_control.set_property('run_simulation_for_weather_file_run_periods', 'No')
      end

      if (@hash['DO_HVAC_SIZING'])
        sim_control.set_property('do_hvac_sizing_simulation_for_sizing_periods', 'Yes')
      else
        sim_control.set_property('do_hvac_sizing_simulation_for_sizing_periods', 'No')
      end

      if (@hash['MAX_HVAC_SIZING_PASSES'].empty?)
        sim_control.set_property('maximum_number_of_hvac_sizing_simulation_passes', '1')
      else
        sim_control.set_property('maximum_number_of_hvac_sizing_simulation_passes', @hash['MAX_HVAC_SIZING_PASSES'])
      end

      # Configure the RunPeriod object
      objects = Plugin.model_manager.input_file.find_objects_by_class_name("RunPeriod")
      if (objects.empty?)
        run_period = JsonInputObject.new("RunPeriod")
        Plugin.model_manager.input_file.add_object(run_period)
      else
        run_period = objects.to_a.first
      end

      run_period.name = @hash['RUN_PERIOD_NAME'] # name of RunPeriod cannot be left blank as of EnergyPlus v9.2
      run_period.set_property('begin_month', @hash['START_MONTH'])
      run_period.set_property('begin_day_of_month', @hash['START_DATE'])
      # Only set year if not empty (epJSON expects integer or omission, not empty string)
      run_period.set_property('begin_year', @hash['START_YEAR'].to_i) unless @hash['START_YEAR'].empty?
      run_period.set_property('end_month', @hash['END_MONTH'])
      run_period.set_property('end_day_of_month', @hash['END_DATE'])
      run_period.set_property('end_year', @hash['END_YEAR'].to_i) unless @hash['END_YEAR'].empty?
      run_period.set_property('day_of_week_for_start_day', @hash['START_DAY'])

      # DLM@20101109: this fix removes a warning in the E+ error file but introduces a fatal error
      # when the last field of the run period object is blank
      # fill in fields to required length
      #(7..11).each {|i| run_period.fields[i] = "" if not run_period.fields[i]}

      return(true)
    end


    def run_simulation
      if (report)
        if (Plugin.simulation_manager.run_simulation)
          close
        end
      end
    end

  end

end
