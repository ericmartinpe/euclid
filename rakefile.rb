# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

root_dir = __dir__
build_dir = "#{root_dir}/build"

require("fileutils")
require("pathname")
require("#{root_dir}/lib/util")
require("#{root_dir}/source/extension/euclid/lib/version")


task :default => :compile


desc "Clean the build directory"
task :clean do
  puts "Cleaning..."

  set_read_write(build_dir)  # Set writable to allow deletion

  # Delete all build files.
  if (File.exist?(build_dir))
    FileUtils.rm_rf(build_dir)

    if (File.exist?(build_dir))
      # Build directory still exists. Sometimes Windows needs some extra time to catch up.
      sleep(0.25)
      FileUtils.rm_rf(build_dir)  # Try again
    end

    if (File.exist?(build_dir))
      # Build directory STILL exists. Maybe something is really locked.
      puts "WARNING: Not all files were cleaned successfully."
      puts "  One or more directories or files may be locked or in use by another program."
      puts "  Close any open files or command consoles and try again."
    end

    FileUtils.mkdir_p(build_dir)  # Restore empty build directory as place holder
  end

  puts "Clean completed."
end


desc "Compile files for local platform from source"  # "Compile" in the sense of assembling something from other sources
task :compile, [:architecture] do |t, args|
  args.with_defaults(:architecture => "win64")

  puts "Compiling..."

  # Relative paths are expanded to absolute paths below.
  if (host_os == :windows)
    if (args[:architecture] == "win64")
      vendor_platform_dir = "source/vendor/platform/win64/"
    elsif (args[:architecture] == "win32")
      vendor_platform_dir = "source/vendor/platform/win32/"
    else
      puts "Unsupported architecture!"
      puts "Task aborted."
      exit
    end

  elsif (host_os == :mac)
    vendor_platform_dir = "source/vendor/platform/mac/"

  else
    puts "Unsupported host operating system!"
    puts "Task aborted."
    exit
  end

  set_read_write(build_dir)  # Set writable to allow overwrite

  # A Rake file or file list task dependency would only detect added or changed files, not deleted files.
  # This 'sync_tree' approach ensures that the source and target directory trees are synchronised while
  # only copying the minimum number of files.

  dir_mappings = [ ["source/extension/", "build/output/extension/"],
                   ["source/legacy_openstudio/", "build/output/extension/euclid/lib/legacy_openstudio/"],
                   ["source/vendor/common/", "build/output/extension/euclid/vendor/"],
                   [vendor_platform_dir, "build/output/extension/euclid/vendor/"] ]

  dir_mappings.each { |dir_mapping| puts "  sync_tree: \"#{dir_mapping[0]}\" -> \"#{dir_mapping[1]}\"" }

  # Expand to absolute paths.
  absolute_mappings = dir_mappings.collect { |m| [File.expand_path(m[0], root_dir), File.expand_path(m[1], root_dir)]  }

  result = sync_tree(*absolute_mappings)
  puts "  #{result[0]} total entries (#{result[1]} added, #{result[2]} deleted, #{result[3]} changed, #{result[4]} unchanged)"

  # Copy a few individual files. These will show up as deleted according to 'sync_tree'.
  FileUtils.cp("#{root_dir}/license.txt", "#{root_dir}/build/output/extension/euclid")
  FileUtils.cp("#{root_dir}/releases.md", "#{root_dir}/build/output/extension/euclid")
  FileUtils.cp("#{root_dir}/readme.md", "#{root_dir}/build/output/extension/euclid")

  set_read_only(build_dir)  # Set read-only to prevent accidental editing

  puts "Compiling completed."
end


desc "Package the installer program for local platform"
task :package, [:architecture] => [:compile] do |t, args|
  args.with_defaults(:architecture => "win64")

  require("zip")

  puts "Packaging..."

  Dir.chdir(root_dir)  # Set working directory for all following shell commands; Git is context sensitive

  # Get current local HEAD commit hash.
  # It is the developer's responsibility to make sure this is the correct commit,
  # for example, there are no other commits to pull.
  commit = `git rev-parse --short --quiet HEAD`
  if (commit)
    commit.chomp!
  end

  # Warn if uncommitted changes in any repository!
  # Subrepos should be recursed.
  #   git status --porcelain
  #   git diff-index --quiet HEAD
  #   git diff --quiet && git diff --cached --quiet

  if (host_os == :windows)
    platform = args[:architecture]
  elsif (host_os == :mac)
    platform = "mac"
  end

  FileUtils.mkdir_p("#{build_dir}/package")
  package_path = "#{build_dir}/package/euclid-#{Euclid::VERSION}-#{platform}-#{commit}.rbz"

  if (File.exist?(package_path))
    FileUtils.rm(package_path)
  end

  output_dir = Pathname.new("#{root_dir}/build/output/extension")
  paths = Pathname.glob("#{root_dir}/build/output/extension/**/{*,.*}")

  zip = Zip::File.open(package_path, Zip::File::CREATE)
  paths.each do |path|
    if (File.extname(path) != ".cache")  # Filter out Energy+.idd.cache files
      #puts "  Adding: #{path}"
      zip.add(path.relative_path_from(output_dir), path)
    end
  end
  puts "  Writing zip at: #{package_path}..."
  zip.close

  puts "  Packaging complete."
end


desc "Compile and package for local platform"
task :build, [:architecture] => [:compile, :package] do |t, args|
  puts "Finishing build..."
  puts "Build complete."
end
