#!/usr/bin/env ruby
# Converts an image file (e.g. a .png file) to a set of Voronoi points with
# colors, using one Voronoi point for each pixel.

require 'bundler/setup'

require 'rmagick'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'mb-geometry'

USAGE = <<-EOF
Usage: #{$0} image.png voronoi.json

Recommend using very small images (e.g. 16x16)
EOF

raise USAGE unless ARGV.length == 2

imgfile, outfile = ARGV
raise "Image file #{imgfile.inspect} not found" unless File.readable?(imgfile)
raise "Output file #{outfile.inspect} exists" if File.exist?(outfile)

img = Magick::Image.read(imgfile)[0]

aspect = img.columns.to_f / img.rows.to_f

points = []

for row in 0...img.rows
  for col in 0...img.columns
    x = 2.0 * aspect * (col + 0.5) / img.columns - aspect
    y = -(2.0 * (row + 0.5) / img.rows - 1)
    px = img.pixel_color(col, row)

    r = px.red.to_f / Magick::QuantumRange
    g = px.green.to_f / Magick::QuantumRange
    b = px.blue.to_f / Magick::QuantumRange
    a = px.alpha.to_f / Magick::QuantumRange

    points << {
      x: x,
      y: y,
      color: [r, g, b, a],
    }
  end
end

info = {
  points: points,
  bounding_box: [ -aspect, -1, aspect, 1 ],
}

File.write(outfile, JSON.pretty_generate(info))
