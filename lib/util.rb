# Copyright (c) 2015-2019 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require 'fileutils'
require 'pathname'
require 'time'


def host_os  # See the 'OS' gem...just don't want another dependency
  case RbConfig::CONFIG['host_os']
  when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
    host_symbol = :windows
  when /darwin|mac os/
    host_symbol = :mac
  when /linux/
    host_symbol = :linux
  when /solaris|bsd/
    host_symbol = :unix
  else
    raise Error::WebDriverError, "unknown os: #{host_os.inspect}"
  end
  return(host_symbol)
end


# This method synchronizes the contents of a target directory tree with the contents
# of one or more source directory trees. Files and directories are added, deleted,
# and copied in order to make the target tree match the sources.
# Usage:  sync_tree( ["source/dir_a/", "build/dir/"], ["source/dir_b/", "build/dir/"], ... )
def sync_tree(*dir_mappings)
  total_count = 0
  add_count = 0
  delete_count = 0
  change_count = 0
  nochange_count = 0

  target_paths_existing = []
  path_mappings = []

  # Merge all directories into one tree and construct a mapping of source paths to target paths.
  dir_mappings.each { |dir_mapping|
    if (dir_mapping.class != Array)
      raise ArgumentError, "Arguments for 'sync_tree' must be a list of arrays of the form [<source_dir>, <target_dir>]"
    end

    source_dir = dir_mapping[0]
    target_dir = dir_mapping[1]
    glob_pattern = dir_mapping[2]  # Optional

    if (not glob_pattern)
      glob_pattern = "**/*"  # Default pattern grabs everything recursively except for 'dot' files
    end

    target_dir = Pathname.new(target_dir).cleanpath
    FileUtils.mkdir_p(target_dir)  # Make sure the target directory exists

    target_dir_paths = Pathname.glob("#{target_dir}/**/*", File::FNM_DOTMATCH)  # Include 'dot' files in case glob pattern includes them
    target_dir_paths.each { |path|
      absolute_path = path.expand_path

      if (not target_paths_existing.include?(absolute_path))  # Skip duplicates
        target_paths_existing << absolute_path
      end
    }

    # Add all parent directories in the target tree so that another source directory does not wipe them out.
    target_dir.descend { |dir|
      absolute_dir = dir.expand_path
      # Check to see if 'dir' already exists from another source path.
      index = path_mappings.index { |m| m[1] == absolute_dir }
      if (not index)
        path_mappings << [nil, absolute_dir]  # No source path!
      end
    }

    source_dir = Pathname.new(source_dir).cleanpath
    source_paths = Pathname.glob("#{source_dir}/#{glob_pattern}")
    source_paths.each { |path|
      relative_path = path.relative_path_from(source_dir)
      target_path = (target_dir + relative_path).expand_path

      # Check to see if 'target_path' already exists from another source path.
      index = path_mappings.index { |m| m[1] == target_path }
      if (index)
        if (path.directory?)
          # Directory collisions are common and can be ignored.

        else
          puts "Collision found! New path will be used.\n  prev: #{path_mappings[index][0]}\n  new: #{path}"
          path_mappings[index][0] = path
        end

      else
        path_mappings << [path, target_path]
      end
    }
  }

  # Evaluate mappings and check for missing or changed files compared to the source paths.
  path_mappings.each { |path_mapping|
    source_path = path_mapping[0]
    target_path = path_mapping[1]

    if (source_path)  # Source paths are nil if they are parent directory nodes for the original target_dir
      if (not target_paths_existing.include?(target_path))
        # Added: path missing from target
        if (source_path.directory?)
          FileUtils.mkdir_p(target_path)

        else
          target_parent_dir = target_path.parent
          if (not File.exist?(target_parent_dir))  # Parent directory might not exist yet
            FileUtils.mkdir_p(target_parent_dir)
          end
          FileUtils.cp(source_path, target_path)
        end
        add_count += 1

      elsif (not FileUtils.uptodate?(target_path, [source_path]))
        # Changed: path found but out-of-date
        if (source_path.directory?)
          # Directories are marked out-of-date when contents change, but no actual change.
          nochange_count += 1
        else
          FileUtils.cp(source_path, target_path)
          change_count += 1
        end

      else
        # Unchanged: path found and up-to-date
        nochange_count += 1
      end

      total_count += 1
    end
  }

  # Check for deleted files compared to the target paths.
  target_paths_existing.each { |target_path_existing|
    index = path_mappings.index { |m| m[1] == target_path_existing }
    if (not index)
      # Deleted: path missing from source
      if (target_path_existing.directory?)
        FileUtils.rm_r(target_path_existing)

      elsif (target_path_existing.exist?)
        FileUtils.rm(target_path_existing)

      else
        # File was already deleted because parent directory was deleted.
      end
      delete_count += 1
    end
  }

  return([total_count, add_count, delete_count, change_count, nochange_count])
end


# Set read-only status on a file or directory (including all contents recursively).
def set_read_only(path)
  if (File.exist?(path))
    if (host_os == :windows)
      if (File.directory?(path))
        `ATTRIB +R "#{path}\\*.*" /S /D`
      else
        `ATTRIB +R "#{path}" /S /D`
      end

    elsif (host_os == :mac)
      `chmod -R a-w "#{path}"`

    else
      puts "Unsupported host operating system!"
    end
  end
end


# Set read-write status on a file or directory (including all contents recursively).
def set_read_write(path)
  if (File.exist?(path))
    if (host_os == :windows)
      if (File.directory?(path))
        `ATTRIB -R "#{path}\\*.*" /S /D`
      else
        `ATTRIB -R "#{path}" /S /D`
      end

    elsif (host_os == :mac)
      `chmod -R u+w "#{path}"`

    else
      puts "Unsupported host operating system!"
    end
  end
end


# Repository dependencies are specified in a .dependencies file in the project root directory.
# Each line of the file defines one dependency in the format:
#
#   <local-directory>,<remote-url>,<commit-reference>  # comment
#
# Blank lines are allowed. End-of-line comments can be included using the # character.
# Directory paths should use / forward slashes. Relative paths are allowed. Spaces in the path are allowed.
# Commit references are either a SHA1 hash or any Git reference/symbol, e.g., "origin/HEAD~2".
# Use "origin/HEAD" as the reference to track the remote head and always pull the latest commit.
def update_dependencies(root_dir)
  puts "Updating dependencies..."

  dependencies_path = "#{root_dir}/.dependencies"
  if (not File.exist?(dependencies_path))
    puts "No .dependencies file found."
    return
  end
  dependencies = File.read(dependencies_path)

  # Store credentials in plain text in project root so that username/password is not always required.
  `git config credential.helper "store --file \\"#{root_dir}/.git-credentials\\""`


  new_dependencies = ""
  dependencies_changed = false

  dependencies.each_line { |line|
    clean_line = line.gsub(/#(.*)/, "").strip  # Strip comments from line
    line_array = clean_line.split(",")
    if (line_array.empty?)
      new_dependencies << line  # Preserve line, even though empty (might have comments only)
      return
    end

    if (line_array.length < 3)
      puts "ERROR: Bad entry in .dependencies file! Format is <local-directory>,<remote-url>,<commit-reference>"
      puts "  Skipping entry: #{line}"
      new_dependencies << line  # Preserve line, even though bad
      return
    end

    relative_dir = line_array[0].strip
    url = line_array[1].strip
    target_commit_ref = line_array[2].strip  # Target reference, could be a hash or reference/symbol

    dir = File.expand_path(relative_dir, root_dir)

    puts "Checking dependency at '#{dir}'..."

    FileUtils.mkdir_p(dir)

    Dir.chdir(dir)  # Set working directory for all following shell commands; Git is context sensitive

    if (Dir.glob("#{dir}/{*,.*}").length < 3)  # Check for empty directory; "." and ".." are first two entries
      # Ping the repository before cloning to avoid annoying "Deletion of directory failed" error message.
      `git ls-remote #{url}`

      if ($?.exitstatus != 0)
        puts "ERROR: Remote repository '#{url}' cannot be reached. Check internet connection."
        puts "  Skipping dependency: #{url}"
        return
      end

      # Clone with credential helper configured to avoid multiple username/password prompts.
      `git clone --config credential.helper="store --file \\"#{root_dir}/.git-credentials\\"" #{url} "#{dir}"`
      `git config build.lastreset "#{Time.now}"`  # Save initial timestamp

      # Cannot skip to 'next' yet. The commit hash must be checked and the local HEAD might need to be reset.

    elsif (File.exist?("#{dir}/.git/config"))
      # Check the current repository URL--it could be different.
      # TO DO: This is currently hard coded to "origin" as the remote!
      current_url = `git config --get remote.origin.url`
      if (current_url)
        current_url.chomp!
      end

      if (current_url.downcase != url.downcase)
        puts "ERROR: Directory '#{dir}' is pointing to a different repository '#{current_url}'! Delete the contents and try again."
        puts "  Skipping dependency: #{url}"
        return
      end

    else
      puts "ERROR: Directory '#{dir}' is not empty! Delete the contents and try again."
      puts "  Skipping dependency: #{url}"
      return
    end

    # By this point, the repository should exist and be the correct one.


    # Check if the user moved the local HEAD via SourceTree or Git command line.

    # Modified time on this file changes every time local HEAD moves in a detached HEAD state.
    timestamp_head = File.stat(".git/HEAD").mtime

    head_file = File.read(".git/HEAD")
    if (head_file =~ /^ref/)
      # The HEAD file starts with "ref" which indicates a reference to a branch tip.
      # Find the branch reference file; it should be: .git/refs/heads/<branch-name>
      ref_file = head_file.scan(/refs.*/)[0]

      # Modified time on this file changes every time local HEAD moves with the branch tip.
      timestamp_ref = File.stat(".git/#{ref_file}").mtime

    else
      # The HEAD file contains a commit hash which indicates a detached HEAD state.
      timestamp_ref = timestamp_head  # Set the same as HEAD because there is no reference
    end

    # The more recent timestamp indicates when the local HEAD last moved according to Git.
    timestamp_git = [timestamp_head, timestamp_ref].max

    # Check when the local HEAD last moved according to build system.
    last_reset = `git config --get build.lastreset`
    if (last_reset.empty?)
      # Config entry missing; assume build system moved the local HEAD last.
      puts "WARNING: build.lastreset missing from Git config file. Timestamp will be reset."
      `git config build.lastreset "#{Time.now}"`  # Save timestamp
      timestamp_build = timestamp_git
    else
      timestamp_build = Time.parse(last_reset)
    end

    if (timestamp_git > timestamp_build)
      # User moved the local HEAD via SourceTree or Git command line.

      # Get new local HEAD commit hash.
      local_commit = `git rev-parse --short --quiet HEAD`
      if (local_commit)
        local_commit.chomp!
      end

      # OPTIONAL: Could try to match the commit with a branch tip and then set the
      # commit reference to the branch name. For now, just use the commit hash.
      new_commit_ref = local_commit

      # Convert references/symbols (e.g., "my-branch") to a hash for comparison.
      target_commit = `git rev-parse --short --quiet #{target_commit_ref}`
      if (target_commit)
        target_commit.chomp!
      end

      if (local_commit != target_commit)
        puts "  User moved the local HEAD. New local commit '#{new_commit_ref}' will be saved in .dependencies file."

        # Search and replace commit reference with new one in .dependencies entry.
        line.gsub!(/#{target_commit_ref}/, new_commit_ref)
        dependencies_changed = true
      end

      `git config build.lastreset "#{Time.now}"`  # Save new timestamp

      target_commit_ref = new_commit_ref
    end


    # Fetch updates if the target commit reference is remote.
    # This handles the case where the user does a pull, but another remote commit is pushed before dependencies are updated.

    # TO DO: This is currently hard coded to "origin" as the remote!
    if (target_commit_ref.downcase == "origin/HEAD".downcase)
      # Always fetch updates for "origin/HEAD" or any remote reference.
      puts "  Fetching updates from remote repositories..."
      `git fetch --all`  # Update local cache from remote repositories

      if ($?.exitstatus != 0)
        puts "ERROR: Remote repository '#{url}' cannot be reached. Check internet connection."
        puts "  Skipping dependency: #{url}"
        return
      end
    end


    # Attempt to find the target commit in the local cache--without doing an unnecessary fetch.
    # Also convert references/symbols (e.g., "my-branch") to a hash for comparison.
    target_commit = `git rev-parse --short --quiet #{target_commit_ref}`

    if ($?.exitstatus != 0)
      puts "  Commit '#{target_commit_ref}' not found in local cache."
      puts "  Fetching updates from remote repositories..."
      `git fetch --all`  # Update local cache from remote repositories

      if ($?.exitstatus != 0)
        puts "ERROR: Remote repository '#{url}' cannot be reached. Check internet connection."
        puts "  Skipping dependency: #{url}"
        return
      end

      # Try to find the target commit again after fetch.
      target_commit = `git rev-parse --short --quiet #{target_commit_ref}`

      if ($?.exitstatus != 0)
        puts "ERROR: Bad commit '#{target_commit_ref}' for remote repository '#{url}'. Fix .dependencies file and try again."
        puts "  Skipping dependency: #{url}"
        return
      end
    end

    if (target_commit)
      target_commit.chomp!
    end


    # Compare local commit and target commit to see if HEAD should be reset.

    local_commit = `git rev-parse --short --quiet HEAD`
    if (local_commit)
      local_commit.chomp!
    end

    git_status = `git status --porcelain`  # Used below

    if (local_commit != target_commit)
      puts "  Current local commit '#{local_commit}' is different from target commit '#{target_commit_ref}'."
      puts "  Target commit '#{target_commit_ref}' will be checked out."
      puts "  To keep working copy at a different commit, edit the entry in .dependencies file."

      if (not git_status.empty?)
        puts "WARNING: Local repository has uncommitted changes. All changes will be preserved."
      end

      `git checkout #{target_commit_ref}`  # Check out a specific commit (creating a detached HEAD) or check out a branch by name

      `git config build.lastreset "#{Time.now}"`  # Save timestamp for this reset to compare later

    else
      if (not git_status.empty?)
        puts "WARNING: Local repository has uncommitted changes."
      end

      puts "  Dependency is up to date."
    end

    new_dependencies << line
  }

  if (dependencies_changed)
    puts "Updating .dependencies file..."

    File.write(dependencies_path, new_dependencies)
  end

  puts "Dependency updates completed."
end
