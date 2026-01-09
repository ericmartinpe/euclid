#!/usr/bin/env ruby

# Test script to check if our new files can load

puts "Testing epJSON file loading..."

begin
  # Set up load path
  $LOAD_PATH.unshift(File.expand_path('../source', __FILE__))
  
  # Try loading in order
  puts "Loading Collection..."
  require_relative 'source/legacy_openstudio/lib/Collection'
  
  puts "Loading JsonInputObject..."
  require_relative 'source/legacy_openstudio/lib/inputfile/JsonInputObject'
  
  puts "Loading FieldMapper..."
  require_relative 'source/legacy_openstudio/lib/inputfile/FieldMapper'
  
  puts "Loading InputObjectAdapter..."
  require_relative 'source/legacy_openstudio/lib/inputfile/InputObjectAdapter'
  
  puts "Loading EpJsonFile..."
  require_relative 'source/legacy_openstudio/lib/inputfile/EpJsonFile'
  
  puts "\n✅ All files loaded successfully!"
  
rescue => e
  puts "\n❌ ERROR loading files:"
  puts e.class
  puts e.message
  puts e.backtrace.first(10)
end
