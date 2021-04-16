#!/usr/bin/env ruby
# See also bin/voronoi_bench.rb

require 'bundler/setup'
Bundler.require

require 'benchmark'

require 'pry'
require 'pry-byebug'

$LOAD_PATH << File.expand_path('../lib', __dir__)

require 'mb-geometry'

v = MB::Geometry::Voronoi.new([{ generator: :random, count: 20 }])
v.set_area_bounding_box(-1, -1, 1, 1)

time = Benchmark.realtime do
  #Lineprof.profile(/./) do
    (-1.0..1.0).step(0.05).each do |y|
      puts y.round(2)
      (-1.0..1.0).step(0.025).each do |x|
        v.natural_neighbors(x, y)
      end
    end
  #end
end

puts "#{time}s"
