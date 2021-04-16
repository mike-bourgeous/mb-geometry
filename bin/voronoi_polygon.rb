#!/usr/bin/env ruby
# Generates equally-spaced points in a large, centered regular polygon, with
# half as many points in a small, centered regular polygon.

require 'rubygems'
require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)
require 'mb-geometry'

raise "Usage: #{$0} sides filename" unless ARGV.size == 2
sides = ARGV[0].to_i
filename = ARGV[1]

puts "Generating a \e[1;34m#{sides}-sided\e[0m regular polygon with a \e[1;35m#{sides / 2}-sided\e[0m smaller polygon in \e[1;36m#{filename}\e[0m"

def offset_poly(sides, radius, offset)
  MB::Geometry::Generators.regular_polygon(sides, radius).map { |v| v.map { |c| c + offset } }
end

p = offset_poly(sides, 250, 300)
p += offset_poly(sides / 2, -50, 300)
v = MB::Geometry::Voronoi.new(p)
v.set_area_bounding_box(0, 0, 600, 600)
v.save_svg(filename)
