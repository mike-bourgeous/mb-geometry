#!/usr/bin/env ruby
# Animates blends between graph files and saves resulting frames to individual
# SVGs.  If ffmpeg is present and has SVG support enabled, it can also generate
# a video file.

require 'bundler/setup'

require 'shellwords'

require 'mb-geometry'

def usage
  puts "\nUsage: \e[1m#{$0}\e[0m output_image.(svg|mp4|mkv|webm|gif) filename.(json|yml|csv) [animate_frames [pause_frames]] [filename|__shuffle [animate_frames [pause_frames]] ...]"
  puts "\nModifiers (always start with two underscores and take the place of a filename):"
  puts "\t\e[1m__shuffle\e[0m - Randomizes the order of the points from the previously loaded file"
  puts "\t\e[1m__cycle\e[0m - Shifts the order of the points from the previously loaded file by one"
  puts "\nExample:"
  puts "\t#{$0} /tmp/polygons.mkv test_data/square.yml 60 test_data/3gon.yml 60 test_data/pentagon.json 60 test_data/zero.csv 180 0"
  puts "\tThis will animate between polygons for 60 frames, pause for 60 frames each time, then fade out over 180."

  exit 1
end

usage if ARGV.include?('--help') || ARGV.length < 2

class Transitionator
  def initialize(argv)
    argv = argv.dup

    @output = argv.shift
    @out_dir = File.dirname(@output)
    @out_ext = File.extname(@output)
    @out_prefix = File.join(@out_dir, File.basename(@output, @out_ext))
    raise "Output location #{@out_dir.inspect} is not a writable directory" unless File.directory?(@out_dir) && File.writable?(@out_dir)

    @transitions = []

    argv.each do |arg|
      if arg =~ /\A\d+\z/
        # This argument is a number of frames for the last file given
        raise "Frame count given before any graph filenames" if @transitions.empty?

        if @transitions.last[:pause]
          raise "Too many frame counts specified for #{transitions.last[:filename]}"
        elsif @transitions.last[:frames]
          @transitions.last[:pause] = arg.to_i
        else
          @transitions.last[:frames] = arg.to_i
        end

      elsif arg =~ /\A__[a-z_]+\z/
        raise "Modifier given before any graph filenames" if @transitions.empty?

        # This argument is a modifier (e.g. __shuffle) for existing data, instead
        # of a new file to render.
        case arg
        when '__shuffle'
          @transitions << { modifier: :shuffle, frames: nil, pause: nil }

        when '__cycle'
          @transitions << { modifier: :cycle, frames: nil, pause: nil }

        else
          raise "Invalid modifier #{arg.inspect}"
        end

      else
        # This argument is a filename
        raise "Input file #{arg.inspect} does not exist or is not readable" unless File.readable?(arg)
        @transitions << { filename: arg, frames: nil, pause: nil }
      end
    end

    raise "No graph filenames/transitions were given" if @transitions.empty?

    @total_frames = @transitions.map { |t| (t[:frames] || 60) + (t[:pause] || t[:frames] || 60)}.sum
    @current_frame = 0
    @digits = Math.log10(@total_frames).ceil rescue 5

    puts "Generating \e[1m#{@total_frames}\e[0m images."

    begin
      MB::U.prevent_mass_overwrite("#{@out_prefix}_#{'?' * @digits}.svg", prompt: true)
    rescue MB::Util::FileMethods::FileExistsError
      puts "\e[1;33mAborting.\e[0m"
      exit 1
    end

    # Load points and compute bounding box
    @xmin = -32.0 / 9.0
    @xmax = 32.0 / 9.0
    @ymin = -2
    @ymax = 2
    @transitions.each do |t|
      bbox = nil

      if t[:filename]
        t[:points] = MB::Geometry::Generators.generate_from_file(t[:filename]) do |f|
          bbox = f[:bounding_box] if f.is_a?(Hash)
        end

        if t[:points].length > 0
          bbox ||= MB::Geometry.bounding_box(t[:points].map { |p| p.values_at(:x, :y) }, 0.001)
          @xmin = bbox[0] if bbox[0] < @xmin
          @ymin = bbox[1] if bbox[1] < @ymin
          @xmax = bbox[2] if bbox[2] > @xmax
          @ymax = bbox[3] if bbox[3] > @ymax
        end
      end
    end

    @xres = ENV['XRES']&.to_i || 1920
    @yres = ENV['YRES']&.to_i || @xres * 9 / 16

    # .mp4 needs even dimensions
    @xres += 1 if @xres.odd?
    @yres += 1 if @yres.odd?

    @aspect = Rational(@xres, @yres)
    puts "Max output resolution is \e[35m#{@xres}x#{@yres}\e[0m with aspect \e[35m#{@aspect.numerator}:#{@aspect.denominator} (#{@aspect.to_f})\e[0m."

    # TODO: Put this bounding box aspect ratio code into MB::Geometry::Voronoi::SVG
    @xcenter = (@xmin + @xmax) / 2.0
    @ycenter = (@ymin + @ymax) / 2.0
    @width = @xmax - @xmin
    @height = @ymax - @ymin
    @bbox_aspect = @width.to_f / @height

    if @bbox_aspect < @aspect
      # Narrower; make wider
      @width *= @aspect / @bbox_aspect
      @xmax = @xcenter + @width / 2.0
      @xmin = @xcenter - @width / 2.0
    elsif @bbox_aspect > @aspect
      # Wider; make taller
      @height *= @bbox_aspect / @aspect
      @ymax = @ycenter + @height / 2.0
      @ymin = @ycenter - @height / 2.0
    end

    @bbox_aspect = @width.to_f / @height

    puts "Bounding box is \e[34m(#{@xmin}, #{@ymin}), (#{@xmax}, #{@ymax})\e[0m with aspect \e[34m#{@bbox_aspect}\e[0m."

    @v = MB::Geometry::Voronoi.new([])
    @v.set_area_bounding_box(@xmin, @ymin, @xmax, @ymax)
    @anim = MB::Geometry::VoronoiAnimator.new(@v)
  end

  def run
    @transitions.each do |t|
      filename = t[:filename] || t[:modifier]
      frames = t[:frames] || 60
      pause = t[:pause] || t[:frames] || 60

      puts "Transition to \e[1;34m#{t[:points]&.length || 'the same'}\e[0m point(s) from \e[1;33m#{filename.inspect}\e[0m over \e[1;35m#{frames}\e[0m frame(s)."

      case t[:modifier]
      when :shuffle
        @anim.shuffle(frames)
        animate

      when :cycle
        @anim.cycle(1, frames)
        animate

      else
        if frames == 0
          @v.replace_points(t[:points])
        else
          @anim.transition(t[:points], frames)
          animate
        end
      end

      puts "Pause for \e[1;35m#{pause}\e[0m frame(s)."
      wait(pause)
    end

    if @out_ext == '.mp4' || @out_ext == '.mkv' || @out_ext == '.webm' || @out_ext == '.gif'
      if @out_ext == '.gif'
        # https://ffmpeg.org/ffmpeg-filters.html#palettegen
        # https://superuser.com/questions/556029/how-do-i-convert-a-video-to-gif-using-ffmpeg-with-reasonable-quality
        opts = "-gifflags +transdiff -r:v 15 -vf 'split [v1][v2] ; [v1] palettegen=stats_mode=diff:reserve_transparent=false:transparency_color=000000 [p] ; [v2][p] paletteuse=dither=none:diff_mode=rectangle:alpha_threshold=0'"
      else
        opts = "-movflags +faststart -pix_fmt yuv420p -crf 12"
      end
      puts "\n\e[36mGenerating \e[1m#{@output}\e[22m with ffmpeg.\e[0m\n\n"
      if !system("ffmpeg -loglevel 24 -r:v 60 -i #{@out_prefix.shellescape}_%0#{@digits}d.svg #{opts} #{@output.shellescape}")
        raise "ffmpeg failed: #{$?}"
      end
    end
  end

  # Saves SVG frames until VoronoiAnimator#update returns false.
  def animate
    while @anim.update
      save_next_frame
    end
  end

  # Saves +n+ static frames.
  def wait(n)
    n.times do
      save_next_frame
    end
  end

  def save_next_frame
    filename = "#{@out_prefix}_#{"%0#{@digits}d" % @current_frame}.svg"
    @v.save_svg(
      filename,
      max_width: @xres,
      max_height: @yres,
      voronoi: ENV['VORONOI'] != '0',
      delaunay: ENV['DELAUNAY'] == '1',
      circumcircles: ENV['CIRCUMCIRCLES'] == '1',
      points: ENV['POINTS'] != '0',
      labels: ENV['LABELS'] == '1'
    )
    @current_frame += 1
  end
end

begin
  Transitionator.new(ARGV).run
rescue => e
  puts "\e[1m#{e}\e[0m\n\t#{e.backtrace.join("\n\t")}"
  usage
end
