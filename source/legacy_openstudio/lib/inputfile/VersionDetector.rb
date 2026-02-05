# OpenStudio
# Copyright (c) 2008-2015, Alliance for Sustainable Energy.  All rights reserved.
# Copyright (c) 2017-2020, Big Ladder Software LLC. All rights reserved.
# See the file "License.txt" for additional terms and conditions.

module LegacyOpenStudio

  # Utility class for detecting EnergyPlus version from IDF and epJSON files
  class VersionDetector
    
    # Detect EnergyPlus version from epJSON file
    # @param epjson_data [Hash] Parsed epJSON data
    # @return [String, nil] Version string like "25-1-0", or nil if no version found
    def self.detect_version_from_epjson(epjson_data)
      # Check for Version object
      if epjson_data["Version"]
        version_obj = epjson_data["Version"].values.first
        if version_obj && version_obj["version_identifier"]
          version = version_obj["version_identifier"].to_s
          # Convert "25.1.0" to "25-1-0" or "25.1" to "25-1-0"
          parts = version.split('.')
          # Ensure we have major, minor, and patch (default patch to 0)
          parts[2] ||= '0'
          return parts.join('-')
        end
      end
      
      # Return nil if no version found
      nil
    end
    
    # Detect EnergyPlus version from IDF file content
    # @param idf_path [String] Path to IDF file
    # @return [String, nil] Version string like "25-1-0", or nil if no version found
    def self.detect_version_from_idf(idf_path)
      # Read entire file to find Version object
      content = File.read(idf_path)
      
      # Look for Version object: Version,\n  25.1.0;
      # This matches various formats:
      #   Version,\n  25.1.0;
      #   Version,25.1.0;
      #   Version, 25.1.0;
      if content.match(/Version\s*,\s*[\r\n]*\s*([\d\.]+)\s*;/i)
        version = $1
        # Convert "25.1.0" to "25-1-0" or "25.1" to "25-1-0" or "25.2" to "25-2-0"
        parts = version.split('.')
        # Ensure we have major, minor, and patch (default patch to 0)
        parts[2] ||= '0'
        return parts.join('-')
      end
      
      # Return nil if no version found
      nil
    rescue
      nil
    end
    
    # Check if version meets minimum requirement (9.6.0)
    # @param version [String] Version string like "25-1-0"
    # @return [Boolean] true if version >= 9.6.0, false otherwise
    def self.meets_minimum_version?(version)
      return false unless version
      
      parts = version.split('-').map(&:to_i)
      major = parts[0] || 0
      minor = parts[1] || 0
      
      # Check if >= 9.6
      return true if major > 9
      return true if major == 9 && minor >= 6
      false
    end
    
  end

end
