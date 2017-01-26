# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

root_dir = File.expand_path(File.dirname(__FILE__))

require("fileutils")
require("pathname")
require("zip")
require("#{root_dir}/extension/euclid/lib/version")


task :default => :package


desc "Package the installer program for local platform"
task :package do
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

  package_path = "#{root_dir}/euclid-#{EuclidExtension::VERSION}-#{commit}.rbz"

  if (File.exist?(package_path))
    FileUtils.rm(package_path)
  end

  output_dir = Pathname.new("#{root_dir}/extension")
  paths = Pathname.glob("#{root_dir}/extension/**/{*,.*}")

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
