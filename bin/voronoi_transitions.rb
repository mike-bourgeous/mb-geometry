#!/usr/bin/env ruby
# Animates blends between graph files and saves resulting frames to individual
# SVGs.  If ffmpeg is present and has SVG support enabled, it can also generate
# a .mp4 file.

require 'bundler/setup'

require 'mb-geometry'

def usage
  puts "\nUsage: \e[1m#{$0}\e[0m output_image.svg filename.(json|yml|csv) [animate_frames [pause_frames]] [filename [animate_frames [pause_frames]] ...]"
  puts "\nExample:\n\t#{$0} /tmp/polygons.svg test_data/square.yml 60 test_data/3gon.yml 60 test_data/pentagon.json 60"

  exit 1
end

def svg_filename(prefix, frame, digits)
  "#{prefix}_#{"%0#{digits}d" % frame}.svg"
end

usage if ARGV.include?('--help') || ARGV.length < 2

begin
  output = ARGV.shift
  out_dir = File.dirname(output)
  out_ext = File.extname(output)
  out_prefix = File.join(out_dir, File.basename(output, out_ext))
  raise "Output location #{out_dir.inspect} is not a writable directory" unless File.directory?(out_dir) && File.writable?(out_dir)

  transitions = []

  ARGV.each do |arg|
    if arg =~ /\A\d+\z/
      # This argument is a number of frames
      raise "Frames specified before any graph filenames" if transitions.empty?
      raise "Frame count specified more than once for #{transitions.last[:filename]}" if transitions.last[:frames]
      transitions.last[:frames] = arg.to_i

    else
      # This argument is a filename
      raise "Input file #{arg.inspect} does not exist or is not readable" unless File.readable?(arg)
      transitions << { filename: arg, frames: nil, pause: nil }
    end
  end

  raise "No graph filenames/transitions were given" if transitions.empty?

  total_frames = transitions.map { |t| (t[:frames] || 1) }.sum

  current_frame = 0
  digits = Math.log10(total_frames).ceil rescue 5

  v = MB::Geometry::Voronoi.new([])
  anim = MB::Geometry::VoronoiAnimator.new(v)

  transitions.each do |t|
    filename = t[:filename]
    frames = t[:frames] || 0
    puts "Transition to \e[1;33m#{t[:filename]}\e[0m over \e[1;35m#{t[:frames] || 0}\e[0m frames."

    points = MB::Geometry::Generators.generate_from_file(filename)

    if frames == 0
      v.replace_points(points)
      v.save_svg(svg_filename(out_prefix, current_frame, digits))
      current_frame += 1
    else
      anim.transition(points, frames)
      while anim.update
        v.save_svg(svg_filename(out_prefix, current_frame, digits))
        current_frame += 1
      end
    end
  end

  if out_ext == '.mp4'
    puts "\n\e[36mGenerating \e[1m#{output}\e[22m with ffmpeg.\e[0m\n\n"
    `ffmpeg -loglevel 24 -r:v 60 -i #{out_prefix}_%0#{digits}d.svg -crf 12 #{out_prefix}.mp4`
  end
rescue => e
  puts "\e[1m#{e}\e[0m\n\t#{e.backtrace.join("\n\t")}"
  usage
end
