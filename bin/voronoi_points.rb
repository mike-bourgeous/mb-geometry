#!/usr/bin/env ruby
# Generates a Voronoi diagram for a list of points given on the command line.
#
# Example: ./bin/voronoi_points.rb linear.svg 1 1 2 1 3 1

require 'rubygems'
require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'mb-geometry'

raise "Usage: #{$0} filename.svg x y [x y ...]" unless ARGV.size >= 3 && ARGV.size.odd?
filename = ARGV[0]
points = ARGV[1..-1].map(&:to_f).each_slice(2).to_a

puts "Generating Voronoi diagram from #{points.size} points"
v = MB::Geometry::Voronoi.new(points)
v.save_svg(filename)
v.save_rubyvor_svg(filename + '-rv.svg') if v.engine == :rubyvor
v.save_delaunay_svg(filename + '-dl-t.svg')
