#!/usr/bin/env ruby
# Animates blends between graph files and saves resulting frames to individual
# SVGs.  If ffmpeg is present and has SVG support enabled, it can also generate
# a .mp4 file.

require 'bundler/setup'

require 'mb-geometry'

def usage
  puts "\nUsage: \e[1m#{$0}\e[0m output_image.(svg|mp4|mkv) filename.(json|yml|csv) [animate_frames [pause_frames]] [filename [animate_frames [pause_frames]] ...]"
  puts "\nExample:"
  puts "\t#{$0} /tmp/polygons.mkv test_data/square.yml 60 test_data/3gon.yml 60 test_data/pentagon.json 60 test_data/zero.csv 180 0"
  puts "\tThis will animate between polygons for 60 frames, pause for 60 frames each time, then fade out over 180."

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

      if transitions.last[:pause]
        raise "Too many frame counts specified for #{transitions.last[:filename]}"
      elsif transitions.last[:frames]
        transitions.last[:pause] = arg.to_i
      else
        transitions.last[:frames] = arg.to_i
      end

    else
      # This argument is a filename
      raise "Input file #{arg.inspect} does not exist or is not readable" unless File.readable?(arg)
      transitions << { filename: arg, frames: nil, pause: nil }
    end
  end

  raise "No graph filenames/transitions were given" if transitions.empty?

  total_frames = transitions.map { |t| (t[:frames] || 1) + (t[:pause] || t[:frames] || 1)}.sum
  current_frame = 0
  digits = Math.log10(total_frames).ceil rescue 5

  puts "Generating \e[1m#{total_frames}\e[0m images."

  existing_files = Dir["#{out_prefix}_#{'?' * digits}.svg"].sort
  unless existing_files.empty?
    loop do
      STDOUT.write "\e[1;33m#{existing_files.length}\e[0m output files like \e[33m#{existing_files.first}\e[0m exist.  Remove them and proceed? \e[1m[Y / N]\e[0m "
      STDOUT.flush

      reply = STDIN.readline # TODO: just require single Y or N character

      case reply
      when /\A[Yy]/
        puts "Deleting files and continuing."
        existing_files.each do |f|
          File.unlink(f)
        end
        break

      when /\A[Nn]/
        puts "Aborting."
        exit 1
      end
    end
  end

  # Load points and compute bounding box
  xmin = -32.0 / 9.0
  xmax = 32.0 / 9.0
  ymin = -2
  ymax = 2
  transitions.each do |t|
    bbox = nil

    t[:points] = MB::Geometry::Generators.generate_from_file(t[:filename]) do |f|
      bbox = f[:bounding_box] if f.is_a?(Hash)
    end

    if t[:points].length > 0
      bbox ||= MB::Geometry.bounding_box(t[:points].map { |p| p.values_at(:x, :y) }, 0.001)
      xmin = bbox[0] if bbox[0] < xmin
      ymin = bbox[1] if bbox[1] < ymin
      xmax = bbox[2] if bbox[2] > xmax
      ymax = bbox[3] if bbox[3] > ymax
    end
  end

  puts "Bounding box is \e[34m(#{xmin}, #{ymin}), #{xmax}, #{ymax})\e[0m."

  v = MB::Geometry::Voronoi.new([])
  v.set_area_bounding_box(xmin, ymin, xmax, ymax)
  anim = MB::Geometry::VoronoiAnimator.new(v)

  transitions.each do |t|
    filename = t[:filename]
    frames = t[:frames] || 0
    pause = t[:pause] || t[:frames] || 1
    puts "Transition to \e[1;34m#{t[:points].length}\e[0m point(s) from \e[1;33m#{filename}\e[0m over \e[1;35m#{frames}\e[0m frame(s)."

    if frames == 0
      v.replace_points(t[:points])
    else
      anim.transition(t[:points], frames)
      while anim.update
        v.save_svg(svg_filename(out_prefix, current_frame, digits), max_width: 1920, max_height: 1080)
        current_frame += 1
      end
    end

    puts "Pause for \e[1;35m#{pause}\e[0m frame(s)."

    pause.times do
      v.save_svg(svg_filename(out_prefix, current_frame, digits), max_width: 1920, max_height: 1080)
      current_frame += 1
    end
  end

  if out_ext == '.mp4' || out_ext == '.mkv'
    puts "\n\e[36mGenerating \e[1m#{output}\e[22m with ffmpeg.\e[0m\n\n"
    `ffmpeg -loglevel 24 -r:v 60 -i #{out_prefix}_%0#{digits}d.svg -crf 12 #{out_prefix}#{out_ext}`
  end
rescue => e
  puts "\e[1m#{e}\e[0m\n\t#{e.backtrace.join("\n\t")}"
  usage
end
