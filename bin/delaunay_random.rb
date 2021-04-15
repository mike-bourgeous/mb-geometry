#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'benchmark'

require 'json'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/geometry/delaunay'

random = Random.new(ENV['RANDOM_SEED']&.to_i || 0)

count = ARGV[0]&.to_i || 100
points = count.times.map {
  [random.rand(-1.0..1.0), random.rand(-1.0..1.0)]
}

t = nil

begin
  t = MB::Geometry::Delaunay.new(points)
rescue => e
  puts "\n\n\e[31mError in triangulation: \e[1m#{e}\e[0m"

  filename = File.join(__dir__, '..', 'test_data', Time.now.strftime("%Y-%m-%d_%H-%M-%S_bad_bench.json"))
  puts "Saving problematic points to \e[1m#{filename}\e[0m\n\n"

  File.write(filename, JSON.pretty_generate(points.sort.map { |p| { x: p[0], y: p[1] } }))

  raise
end

File.write('/tmp/delaunay_random.json', JSON.pretty_generate(t.to_h))
