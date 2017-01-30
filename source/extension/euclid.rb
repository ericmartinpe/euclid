# Copyright (c) 2017 Big Ladder Software LLC. All rights reserved.
# See the file "license.txt" for additional terms and conditions.

require("extensions")

begin
  require("fileutils")
  require("tmpdir")
rescue LoadError
  require("euclid/lib/legacy_openstudio/stdruby/fileutils")
  require("euclid/lib/legacy_openstudio/stdruby/tmpdir")
end


require("euclid/lib/version")

EUCLID_EXTENSION_NAME = "Euclid"

extension = SketchupExtension.new(EUCLID_EXTENSION_NAME, "euclid/lib/legacy_openstudio/lib/Startup")
extension.name = EUCLID_EXTENSION_NAME
extension.description = "Adds building energy modeling capabilities by coupling SketchUp to various simulation engines."
extension.version = EuclidExtension::VERSION
extension.creator = "Big Ladder Software"
extension.copyright = "2017 Big Ladder Software LLC; 2008-2015 Alliance for Sustainable Energy"

Sketchup.register_extension(extension, true)
