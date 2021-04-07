#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'json'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/delaunay'

if ARGV.length != 1
  puts "\nUsage: \e[1m#{$0}\e[0m file_with_points_array.json (or .yml)"
  puts "\nJSON or YML should be of the form [ { \"x\": 0, \"y\": 0 }, ... ]"
  exit 1
end

# TODO: Merge with Geometry::Voronoi.generate_from_file when this project is merged with that one
case File.extname(ARGV[0])
when '.json'
  points = JSON.parse(File.read(ARGV[0]), symbolize_names: true)

when '.yaml', '.yml'
  points = YAML.load(File.read(ARGV[0]), symbolize_names: true)

else
  raise "Unknown extension #{File.extname(ARGV[0])}"
end

t = MB::Delaunay.new(points.map { |p| [p[:x], p[:y]] })

# TODO: Use MB::Sound::U.highlight after refactoring utilities elsewhere
puts Pry::ColorPrinter.pp(
  t.points.sort.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h,
  '',
  80
)
