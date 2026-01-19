# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# See the file "License.txt" for additional terms and conditions.

require("fileutils")
require("tmpdir")


module LegacyOpenStudio

  class SimulationManager

    def initialize
      @output_dir = nil
      @active_thread = nil
    end

    def run_simulation

      run_weather_file = false

      # check that new file has been saved
      if not Plugin.model_manager.input_file.path
        UI.messagebox("Please save your input file before simulating in EnergyPlus.")
        return(false)
      end

      # Read the SimulationControl object
      if (objects = Plugin.model_manager.input_file.find_objects_by_class_name("SimulationControl"))
        sim_control = objects.to_a.first
        run_weather = sim_control.get_property('run_simulation_for_weather_file_run_periods', 'Yes')
        if (run_weather.to_s.upcase == "YES")
          run_weather_file = true

          # Check the weather file
          epw_path = Plugin.model_manager.get_attribute("Weather File Path")
          if (epw_path.empty?)
            UI.messagebox("You must specify a weather file to run a weather file simulation.  Correct the EPW path and try again.")
            return(false)
          elsif (not File.exists?(epw_path))
            UI.messagebox("Cannot locate the weather file.  Correct the EPW path and try again.")
            return(false)
          end
        end
      end

      # Use the default EnergyPlus path (which should have been set when file was opened)
      energyplus_path = Plugin.energyplus_path
      energyplus_dir = Plugin.energyplus_dir

      if (!energyplus_path || !File.exists?(energyplus_path))
        UI.messagebox("Cannot locate the EnergyPlus engine.  Correct the EXE path and try again.")
        Plugin.dialog_manager.show(PreferencesInterface)
        return(false)
      end

      idd_path = energyplus_dir + "/Energy+.idd"
      if (not File.exists?(idd_path))
        UI.messagebox("Cannot locate the input data dictionary (IDD) in the EnergyPlus directory.  Correct the EXE path and try again.")
        Plugin.dialog_manager.show(PreferencesInterface)
        return(false)
      end

      version_string = DataDictionary.version(idd_path)
      version = Gem::Version.new(version_string)
      if (not Plugin.energyplus_version.satisfied_by?(version))
        puts "INFO: Using EnergyPlus #{version} (file version: #{file_version}) - Path: #{energyplus_path}"
      end

      # Save energyplus_dir as instance variable for use in on_completion
      @energyplus_dir = energyplus_dir

      if (Plugin.model_manager.input_file_dir.nil?)
        output_dir = ""
        @output_dir = energyplus_dir
      else
        output_dir = Plugin.model_manager.input_file_dir  #.split("/").join("\\")  # Fix the file separator to work with DOS
        @output_dir = output_dir  # Save the current output dir so that the same one is used by 'on_completion'
      end


      weather_file_path = Plugin.model_manager.get_attribute("Weather File Path")
      if (weather_file_path.nil?)
        weather_file_path = ""
      else
        weather_file_path = weather_file_path  #.split("/").join("\\")  # Fix the file separator to work with DOS
      end


      # Copy the input file so that permanent changes are not made to the original input file.
      new_input_file = Plugin.model_manager.input_file.copy

      # do first so we don't remove requests added later
      if (not Plugin.model_manager.get_attribute("Report User Variables"))
        # Probably shouldn't be able to access .objects directly!
        new_input_file.objects.remove_if { |object| object.is_class_name?("Output:Variable") or object.is_class_name?("Output:Meter") }
      end

      if (Plugin.model_manager.get_attribute("Report ABUPS"))
        new_input_file.objects.remove_if { |object| object.is_class_name?("Output:Table:SummaryReports") or object.is_class_name?("OutputControl:Table:Style") }

        format = Plugin.model_manager.get_attribute("ABUPS Format")
        units = Plugin.model_manager.get_attribute("ABUPS Units")

        if units == "IP"
          new_input_file.add_object(JsonInputObject.new("OutputControl:Table:Style", "OutputControl:Table:Style 1", {
            "column_separator" => format,
            "unit_conversion" => "InchPound"
          }))
        else
          new_input_file.add_object(JsonInputObject.new("OutputControl:Table:Style", "OutputControl:Table:Style 1", {
            "column_separator" => format
          }))
        end

        new_input_file.add_object(JsonInputObject.new("Output:Table:SummaryReports", "Output:Table:SummaryReports 1", {
          "reports" => [{"report_name" => "AnnualBuildingUtilityPerformanceSummary"}]
        }))
      end

      if (Plugin.model_manager.get_attribute("Report Sql"))
        # Probably shouldn't be able to access .objects directly!
        new_input_file.objects.remove_if { |object| object.is_class_name?("Output:SQLite")}
        new_input_file.add_object(JsonInputObject.new("Output:SQLite", "Output:SQLite 1", {
          "option_type" => "SimpleAndTabular"
        }))
      end

      if (Plugin.model_manager.get_attribute("Report DXF"))
        # Probably shouldn't be able to access .objects directly!
        new_input_file.objects.remove_if { |object| object.is_class_name?("Output:Surfaces:Drawing")}
        new_input_file.add_object(JsonInputObject.new("Output:Surfaces:Drawing", "Output:Surfaces:Drawing 1", {
          "report_type" => "DXF"
        }))
      end

      if (Plugin.model_manager.get_attribute("Report Zone Temps"))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Zone Mean Air Temperature", {
          "key_value" => "*",
          "variable_name" => "Zone Mean Air Temperature",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Zone Mean Radiant Temperature", {
          "key_value" => "*",
          "variable_name" => "Zone Mean Radiant Temperature",
          "reporting_frequency" => "Hourly"
        }))
      end

      if (Plugin.model_manager.get_attribute("Report Surface Temps"))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Surface Inside Face Temperature", {
          "key_value" => "*",
          "variable_name" => "Surface Inside Face Temperature",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Surface Outside Face Temperature", {
          "key_value" => "*",
          "variable_name" => "Surface Outside Face Temperature",
          "reporting_frequency" => "Hourly"
        }))
      end

      if (Plugin.model_manager.get_attribute("Report Daylighting"))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Daylighting RP1 Illuminance", {
          "key_value" => "*",
          "variable_name" => "Daylighting Reference Point 1 Illuminance",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Daylighting RP1 Glare Index", {
          "key_value" => "*",
          "variable_name" => "Daylighting Reference Point 1 Glare Index",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Daylighting RP2 Illuminance", {
          "key_value" => "*",
          "variable_name" => "Daylighting Reference Point 2 Illuminance",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Daylighting RP2 Glare Index", {
          "key_value" => "*",
          "variable_name" => "Daylighting Reference Point 2 Glare Index",
          "reporting_frequency" => "Hourly"
        }))
      end

      if (Plugin.model_manager.get_attribute("Report Zone Loads"))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Zone Ideal Loads Sensible Heating Rate", {
          "key_value" => "*",
          "variable_name" => "Zone Ideal Loads Supply Air Sensible Heating Rate",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Zone Ideal Loads Sensible Cooling Rate", {
          "key_value" => "*",
          "variable_name" => "Zone Ideal Loads Supply Air Sensible Cooling Rate",
          "reporting_frequency" => "Hourly"
        }))
        new_input_file.add_object(JsonInputObject.new("Output:Variable", "Output:Variable Zone Ideal Loads Total Cooling Rate", {
          "key_value" => "*",
          "variable_name" => "Zone Ideal Loads Supply Air Total Cooling Rate",
          "reporting_frequency" => "Hourly"
        }))
      end

      # make a temp directory to run in
      run_dir = Dir.tmpdir + "/EuclidSim/run"
      if not File.directory?(run_dir)
        FileUtils.mkdir_p(run_dir)
      end

      # name of current file
      input_file_name = Plugin.model_manager.input_file_name

      # Clean the output directory
      FileUtils.cd(output_dir)
      base_name = File.basename(input_file_name, '.*')
      FileUtils.rm_f(base_name + '.expidf')
      FileUtils.rm_f(base_name + '.err')
      FileUtils.rm_f(base_name + '.eio')
      FileUtils.rm_f(base_name + '.eso')
      FileUtils.rm_f(base_name + '.sql')
      FileUtils.rm_f(base_name + '.mdd')
      FileUtils.rm_f(base_name + '.mtd')
      FileUtils.rm_f(base_name + '.rdd')
      FileUtils.rm_f(base_name + '.dxf')
      FileUtils.rm_f(base_name + '.csv')
      FileUtils.rm_f(base_name + '-ABUPS.htm')
      FileUtils.rm_f(base_name + '-ABUPS.csv')
      FileUtils.rm_f(base_name + '-ABUPS.tab')
      FileUtils.rm_f(base_name + '-ABUPS.txt')
      FileUtils.rm_f(base_name + '-OutputIlluminanceMap.csv')

      # Clean the run directory
      FileUtils.cd(run_dir)
      FileUtils.rm_f(Dir.glob('*.*'))

      # Write epJSON file to run directory
      new_input_file.write(run_dir + "/in.epJSON")
      if (Plugin.model_manager.get_attribute("Report User Variables") or
          Plugin.model_manager.get_attribute("Report Zone Temps") or
          Plugin.model_manager.get_attribute("Report Surface Temps") or
          Plugin.model_manager.get_attribute("Report Zone Loads") or
          Plugin.model_manager.get_attribute("Report Daylighting"))
        @readvars_flag = true
      else
        @readvars_flag = false
      end

      # Copy idd file to run directory
      FileUtils.cp(idd_path, run_dir + '/Energy+.idd')

      # Copy weather file to run directory
      if (run_weather_file)
        FileUtils.cp(weather_file_path, run_dir + '/in.epw') if (File.exist?(weather_file_path))
      end

      # define where expand objects is
      expandobjects_path = ''
      if (Plugin.platform == Platform_Windows)
        expandobjects_path = energyplus_dir + '/ExpandObjects.exe'
      else
        expandobjects_path = energyplus_dir + '/expandobjects'
      end

      # run expand objects
      if File.exists?(expandobjects_path)
        # call command and wait for process to complete
        system("#{expandobjects_path}")

        if File.exists?(run_dir + "/expanded.idf")
          # copy the expanded.idf to in.expidf
          FileUtils.cp(run_dir + "/expanded.idf", run_dir + "/in.expidf")

          # overwrite in.idf with the expanded file
          if File.exists?(run_dir + "/in.idf")
            File.rename(run_dir + "/in.idf", run_dir + "/in.idf.original")
          end

          File.rename(run_dir + "/expanded.idf", run_dir + "/in.idf")
        end
      end

      # A better alternative to sending shell commands is to use IO.popen to read and write directly to the process.
      if (Plugin.platform == Platform_Windows)
        if (Plugin.model_manager.get_attribute("Close Shell"))
          @active_thread = UI.shell_command('call "' + energyplus_path + '"')
        else
          @active_thread = UI.shell_command('call "' + energyplus_path + '" && pause')
        end

      else
        # Automatic close shell feature doesn't work on Mac yet.
        UI.messagebox("EnergyPlus will be launched in a new instance of the Terminal application.\n\nAfter the simulation is finished, you MUST quit out of the Terminal application before any Actions On Completion will be started.")

        if (@readvars_flag)
          readvars_path = energyplus_dir + "/PostProcess/ReadVarsESO"
        else
          readvars_path = ''
        end

        # This shell command MUST have "open -W" in it or thread will die immediately.
        # Environment variables are used to pass arguments to the "open" child process.
        @active_thread = UI.shell_command("run_dir='" + run_dir + "'\nexport run_dir\nengine_path='" + energyplus_path + "'\nexport engine_path\nreadvars_path='" + readvars_path + "'\nexport readvars_path\nopen -W -F -n '" + Plugin.dir + "/run/run_energyplus'")
      end

      Sketchup.active_model.active_view.animation = self
    end


    def on_completion
      base_name = File.basename(Plugin.model_manager.input_file_name, ".*")
      run_dir = Dir.tmpdir + "/OpenStudio/run/"
      output_dir = @output_dir
      editor_path = Plugin.read_pref("Text Editor Path")

      begin

        FileUtils.cd(run_dir)
        FileUtils.cp('in.expidf', output_dir + '/' + base_name + '.expidf') if (File.exist?('in.expidf'))
        FileUtils.cp('eplusout.err', output_dir + '/' + base_name + '.err') if (File.exist?('eplusout.err'))
        FileUtils.cp('eplusout.eio', output_dir + '/' + base_name + '.eio') if (File.exist?('eplusout.eio'))
        FileUtils.cp('eplusout.eso', output_dir + '/' + base_name + '.eso') if (File.exist?('eplusout.eso'))
        FileUtils.cp('eplusout.sql', output_dir + '/' + base_name + '.sql') if (File.exist?('eplusout.sql'))
        FileUtils.cp('eplusout.mdd', output_dir + '/' + base_name + '.mdd') if (File.exist?('eplusout.mdd'))
        FileUtils.cp('eplusout.mtd', output_dir + '/' + base_name + '.mtd') if (File.exist?('eplusout.mtd'))
        FileUtils.cp('eplusout.rdd', output_dir + '/' + base_name + '.rdd') if (File.exist?('eplusout.rdd'))
        FileUtils.cp('eplusout.dxf', output_dir + '/' + base_name + '.dxf') if (File.exist?('eplusout.dxf'))
        FileUtils.cp('eplustbl.htm', output_dir + '/' + base_name + '-ABUPS.htm') if (File.exist?('eplustbl.htm'))
        FileUtils.cp('eplustbl.csv', output_dir + '/' + base_name + '-ABUPS.csv') if (File.exist?('eplustbl.csv'))
        FileUtils.cp('eplustbl.tab', output_dir + '/' + base_name + '-ABUPS.tab') if (File.exist?('eplustbl.tab'))
        FileUtils.cp('eplustbl.txt', output_dir + '/' + base_name + '-ABUPS.txt') if (File.exist?('eplustbl.txt'))
        FileUtils.cp('eplusmap.csv', output_dir + '/' + base_name + '-OutputIlluminanceMap.csv') if (File.exist?('eplusmap.csv'))

        if (@readvars_flag)
          if (Plugin.platform == Platform_Windows)
            readvars_path = @energyplus_dir + "/PostProcess/ReadVarsESO.exe"
            if not File.exist?(readvars_path)
              readvars_path = @energyplus_dir + "/readvars.exe"
            end
          else
            readvars_path = @energyplus_dir + "/PostProcess/ReadVarsESO"
          end

          if (File.exist?(readvars_path))
            if (Plugin.platform == Platform_Windows)
              UI.shell_command('call "' + readvars_path + '"', false)  # Called synchronously, might want to do this differently

            else
              # Calling synchronously crashes SketchUp on the Mac
              #UI.shell_command('"' + readvars_path + '"')  #, false)

              # Readvars was called earlier from the shell script instead
            end

            FileUtils.cp('eplusout.csv', output_dir + '/' + base_name + '.csv') if (File.exist?('eplusout.csv'))
          else
            UI.messagebox('Cannot find the program "' + readvars_path + '".' + "\nUnable to generate the CSV file.")
          end
        end


        # Difficult to control order in which files open (asynchronous) so that they stack up with ERR on top
        # Could monitor each thread to see when it finishes before opening the next file.

        if (Plugin.model_manager.get_attribute("Show ERR"))
          err_path = @output_dir + "/" + base_name + ".err"
          if (File.exists?(err_path))
            # Open with the preferred text editor
            if (not editor_path.nil? and File.exists?(editor_path))

            # Plugin.open_in_text_editor(path)  # cross-platform method.... or .run_application

              if (Plugin.platform == Platform_Windows)
                UI.shell_command('"' + editor_path + '" "' + err_path + '"')
              else
                UI.shell_command('open -a "' + editor_path + '" "' + err_path + '"')
              end
            else
              UI.messagebox("Cannot open the error file.\nYou do not have a valid text editor in your Preferences.")
              Plugin.dialog_manager.show(PreferencesInterface)
            end

          else
            puts "Could not find the ERR file."
          end
        end

        if (Plugin.model_manager.get_attribute("Show ABUPS"))

          case (Plugin.model_manager.get_attribute("ABUPS Format").upcase)
          when "HTML"
            ext = "htm"
          when "COMMA"
            ext = "csv"
          when "TAB"
            ext = "tab"
          when "FIXED"
            ext = "txt"
          end

          abups_path = @output_dir + "/" + base_name + "-ABUPS." + ext
          if (File.exists?(abups_path))

            if (ext == "htm" or ext == "csv")
              # Open with default web browser or Excel (assuming it's installed!)
              UI.open_external_file(abups_path)
            else
              # Open with the preferred text editor
              if (not editor_path.nil? and File.exists?(editor_path))
                if (Plugin.platform == Platform_Windows)
                  UI.shell_command('"' + editor_path + '" "' + abups_path + '"')
                else
                  UI.shell_command('open -a "' + editor_path + '" "' + abups_path + '"')
                end
              else
                UI.messagebox("Cannot open the ABUPS file.\nYou do not have a valid text editor in your Preferences.")
                Plugin.dialog_manager.show(PreferencesInterface)
              end

            end

          else
            puts "Could not find the ABUPS file."
          end
        end

        if (Plugin.model_manager.get_attribute("Show CSV"))
          csv_path = @output_dir + "/" + base_name + ".csv"
          if (File.exists?(csv_path))
            UI.open_external_file(csv_path)
          else
            puts "Could not find the CSV file."
          end
        end

      rescue Exception => e
        UI.messagebox("Error when performing post processing: '#{e}'\nSimulation results in #{run_dir}", MB_OK)
      end

    end


    def busy?
      return(not @active_thread.nil?)
    end


    # kludge to get background thread to run
    def nextFrame(view)
      if (@active_thread.nil? or not @active_thread.alive?)
        @active_thread = nil
        Sketchup.active_model.active_view.animation = nil
        on_completion
      else
        view.show_frame(0.5)  # Must be called to ensure that nextFrame is called repeatedly
      end
    end

  end

end
