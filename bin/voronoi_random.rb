#!/usr/bin/env ruby
# Generates random points in a Voronoi diagram.

require 'rubygems'
require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'mb-geometry'

raise "Usage: #{$0} points filename" unless ARGV.size == 2
points = ARGV[0].to_i
filename = ARGV[1]

puts "Generating \e[1;34m#{points}\e[0m random points in \e[1;36m#{filename}\e[0m"

p = points.times.map { [rand(2950) + 25, rand(1950) + 25] }

# Sort before annealing (more jagged)
#p.sort_by! { |x, y| Math.atan2(y - 300, x - 300) } # Clockwise colors
#p.sort_by! { |x, y| (y - 300) ** 2 + (x - 300) ** 2 } # Center distance colors
#p.sort_by! { |x, y| y ** 2 + x ** 2 } # Corner distance colors
#p.sort_by! { |x, y| ((y - 600) ** 2 + (x - 300) ** 2) % 200000 } # Rainbow distance colors
#p.sort_by! { |x, y| 50 * (6 + Math.atan2(y - 1000, x - 1500)) + Math.sqrt((y - 1000) ** 2 + (x - 1500) ** 2) } # Spiralish
#p.sort_by! { |x, y| 2.0 * Math.atan2(y - 1000, x - 1500) + 0.015 * Math.sqrt((y - 1000) ** 2 + (x - 1500) ** 2) } # More spiralish
#p.sort_by! { |x, y| -Math.atan2(y - 1000, x - 1500) + (0.01 * Math.sqrt((y - 1000) ** 2 + (x - 1500) ** 2)) % (2.0 * Math::PI) } # Quite spiralish
#p.sort_by! { |x, y| (3.0 * Math.atan2(y - 1000, x - 1500) + 0.01 * Math.sqrt((y - 1000) ** 2 + (x - 1500) ** 2)) % (2.0 * Math::PI) } # Spiral arms

puts 'Initializing diagram'
v = MB::Geometry::Voronoi.new(p)
v.set_area_bounding_box(0, 0, 3000, 2000)

puts 'Generating Voronoi'
v.cells.first.neighbors

puts 'Annealing points'
3.times do v.anneal end

puts 'Regenerating Voronoi'

# Sort after annealing (more uniform)
arms = 5
p = v.cells.map(&:point).sort_by! { |x, y| (arms * Math.atan2(y - 1000, x - 1500) + 0.008 * Math.sqrt((y - 1000) ** 2 + (x - 1500) ** 2)) % (2.0 * Math::PI) } # Spiral arms

v = MB::Geometry::Voronoi.new(p)
v.cells.first.neighbors

puts 'Saving svg'
v.save_svg(filename, max_width: 3000, max_height: 2000, points: false)
