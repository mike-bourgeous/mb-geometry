#!/usr/bin/env ruby
# Generates a Voronoi diagram for points from a given file.

require 'bundler/setup'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'mb-geometry'

raise "Usage: [XRES=width YRES=height] #{$0} points_filename.(json|yml|csv) image.svg" unless ARGV.length == 2
raise "SVG file #{ARGV[1]} already exists" if File.exist?(ARGV[1])
raise "SVG file must end in .svg" unless File.extname(ARGV[1]) == '.svg'

xres = ENV['XRES']&.to_i || 1920
yres = ENV['YRES']&.to_i || xres * 9 / 16
aspect = Rational(xres, yres)

raw_hash = nil
points = MB::Geometry::Generators.generate_from_file(ARGV[0]) { |d|
  d = {points: d} if d.is_a?(Array)
  raw_hash = d # FIXME: better way of getting other data from the file
}

v = MB::Geometry::Voronoi.new(points, sigfigs: 8)
v.set_area_bounding_box(-2.0 * aspect, -2, 2.0 * aspect, 2)

box = raw_hash[:expanded_box] || raw_hash[:bounding_box] || raw_hash[:original_box]
v.set_area_bounding_box(*box) if box

v.save_svg(ARGV[1], voronoi: ENV['VORONOI'] != '0', delaunay: ENV['DELAUNAY'] == '1', circumcircles: ENV['CIRCUMCIRCLES'] == '1', max_width: xres, max_height: yres)
v.save_rubyvor_svg(ARGV[1] + '-rv.svg') if v.engine == :rubyvor
v.save_delaunay_svg(ARGV[1] + '-dl-t.svg')
