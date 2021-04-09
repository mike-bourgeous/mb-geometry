#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'benchmark'

require 'json'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/delaunay'

random = Random.new(ENV['RANDOM_SEED']&.to_i || 0)

preferred_numbers = [1, 2, 3, 5, 8]
exponents = [1, 2, 3]

counts = exponents.flat_map { |x|
  preferred_numbers.map { |n| n * 10 ** x }
}

puts "Testing #{counts}"

v = nil
t = nil

elapsed = {}
triangles = {}

begin
  counts.each do |c|
    puts "Testing with \e[1m#{c}\e[0m points"

    points = c.times.map {
      [random.rand(-1.0..1.0), random.rand(-1.0..1.0)]
    }

    elapsed[c] = {
      base: Benchmark.realtime do
        100.times do
          v = MB::Delaunay.new(points)
        end
      end,
      triangles: Benchmark.realtime do
        100.times do
          t = v.triangles
        end
      end
    }
  end

rescue => e
  puts "\n\n\e[31mError in triangulation: \e[1m#{e}\e[0m"

  filename = File.join(__dir__, '..', 'test_data', Time.now.strftime("%Y-%m-%d_%H-%M-%S_bad_bench.json"))
  puts "Saving problematic points to \e[1m#{filename}\e[0m\n\n"

  File.write(filename, JSON.pretty_generate(points.sort.map { |p| { x: p[0], y: p[1] } }))

  raise
end

puts Pry::ColorPrinter.pp(elapsed, '', 80)
