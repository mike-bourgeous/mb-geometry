#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'json'
require 'benchmark'

$:.unshift(File.join(__dir__, '..', 'lib'))

if $DEBUG || ENV['DEBUG']
  require 'mb/delaunay_debug'
else
  require 'mb/delaunay'
end

if ARGV.length < 1
  puts "\nUsage: \e[1m#{$0}\e[0m file_with_points_array.json (or .yml) [more files...]"
  puts "\nJSON or YML should be of the form [ { \"x\": 0, \"y\": 0 }, ... ]"
  exit 1
end

until ARGV.empty?
  # TODO: Merge with Geometry::Voronoi.generate_from_file when this project is merged with that one
  puts "Triangulating \e[1;36m#{ARGV[0]}\e[0m"

  case File.extname(ARGV[0])
  when '.json'
    points = JSON.parse(File.read(ARGV[0]), symbolize_names: true)

  when '.yaml', '.yml'
    points = YAML.load(File.read(ARGV[0]), symbolize_names: true)

  else
    raise "Unknown extension #{File.extname(ARGV[0])}"
  end

  points = points[:points] if points.is_a?(Hash)

  t = nil
  elapsed = Benchmark.realtime do
    t = MB::Delaunay.new(points.map { |p| p.is_a?(Array) ? p : [p[:x], p[:y], p[:name]] })
  end

  puts "Triangulated \e[1m#{points.length}\e[0m points in \e[1m#{elapsed}\e[0m seconds."

  # TODO: Use MB::Sound::U.highlight after refactoring utilities elsewhere
  puts Pry::ColorPrinter.pp(
    t.points.sort.map { |p| [ [p.x, p.y], p.neighbors.sort.map { |n| [n.x, n.y] } ] }.to_h,
    '',
    80
  )

  ARGV.shift
end
