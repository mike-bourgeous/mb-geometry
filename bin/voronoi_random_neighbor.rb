#!/usr/bin/env ruby
# Moves a sample point around a random set of points, saving a natural neighbor
# visualization to an SVG file for a given number of frames (-1 for infinite).
# If the filename contains a sequence of pound symbols in its basename, then
# multiple files will be created with sequential numbering.
#
# A video can be made of SVGs like so:
# bin/voronoi_random_neighbor.rb 8 1200 /tmp/q####.svg
# ffmpeg -r:v 60 -i /tmp/q%04d.svg /tmp/q.mp4 -crf 12

require 'rubygems'
require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'mb-geometry'

raise "Usage: #{$0} num_points num_frames(-1 for infinite) filename(optional #### replaced with number)" unless ARGV.size == 3
points = ARGV[0].to_i

dirname = File.expand_path(File.dirname(ARGV[2]))
raise "#{dirname.inspect} is not an extant directory" unless File.directory?(dirname)

basename = File.basename(ARGV[2], ".svg")

frames = ARGV[1].to_i
digits = Math.log10(frames).ceil rescue 5
digits = [digits, basename.sub(/^[^#]*(#+)($|.*)/, '\1').size].max
frame_format = "%0#{digits}d"

x = rand(-0.75..0.75)
y = rand(-0.75..0.75)
dx = rand(0.005..0.01) * (rand > 0.5 ? -1 : 1)
dy = rand(0.005..0.01) * (rand > 0.5 ? -1 : 1)

p = points.times.map { [rand(-1.9..1.9), rand(-0.9..0.9)] }
v = MB::Geometry::Voronoi.new(p)
v.set_area_bounding_box(-1.92, -1.08, 1.92, 1.08)

frame = 0
loop do
  filename = File.join(dirname, "#{basename.sub(/#+/, frame_format % frame)}.svg")
  puts "Saving \e[1m#{filename.inspect}\e[0m"
  v.save_neighbor_svg(filename, [x, y], max_width: 1920, max_height: 1080)

  x += dx
  y += dy

  if x >= 1.9 || x <= -1.9
    dx = -dx
  end

  if y >= 1.06 || y <= -1.06
    dy = -dy
  end

  if frames < 0
    sleep 0.01
  else
    frame += 1
    break if frame >= frames
  end
end
