module MB::Geometry
  class Voronoi
    # SVG routines meant to be included in the Voronoi class.  Moved here to
    # keep the Voronoi class itself from getting too huge.
    module SVG
      # Converts HSV in the range 0..1 to RGB in the range 0..1.  Alpha is
      # returned unmodified if present, omitted if nil.
      def self.hsv_to_rgb(h, s, v, a = nil, buf: [])
        # https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_RGB

        h = h.to_f
        s = s.to_f
        v = v.to_f

        h = 0 if h.nan?
        h = 0 if h < 0 && h.infinite?
        h = 1 if h > 1 && h.infinite?
        h = h % 1 if h < 0 || h > 1
        c = v.to_f * s.to_f
        h *= 6.0
        x = c.to_f * (1 - ((h % 2) - 1).abs)
        case h.floor
        when 0
          r, g, b = c, x, 0
        when 1
          r, g, b = x, c, 0
        when 2
          r, g, b = 0, c, x
        when 3
          r, g, b = 0, x, c
        when 4
          r, g, b = x, 0, c
        else
          r, g, b = c, 0, x
        end

        m = v - c

        buf[0] = r + m
        buf[1] = g + m
        buf[2] = b + m

        if a
          buf[3] = a
        else
          buf.delete_at(3)
        end

        buf
      end

      SATURATION_LOOP = [175, 157, 165, 141, 162]
      VALUE_LOOP = [195, 186, 202, 178]

      # Returns an array of [h, s, l] for the +index+th color if there are
      # +total+ colors in the generated palette, in the range [0..360, 0..255,
      # 0..255].
      def self.generate_hsv(index, total)
        h = index * 360.0 / total
        s = SATURATION_LOOP[index % SATURATION_LOOP.length]
        l = VALUE_LOOP[index % VALUE_LOOP.length]
        [h, s, l]
      end

      # Returns an array of [r, g, b[, a]] for the +index+th color if there are
      # +total+ colors, in the range 0..1.  +:alpha+ is returned in the color
      # array if given (TODO: remove alpha and let callers handle it).
      def self.generate_rgb(index, total, alpha: nil)
        h, s, l = generate_hsv(index, total)
        hsv_to_rgb(h / 360.0, s / 255.0, l / 255.0, alpha)
      end

      # Used internally.  Returns an SVG state Hash containing the SVG size,
      # scaling ranges, and a String with an SVG header.
      def start_svg(max_width, max_height)
        max_aspect = max_width.to_f / max_height
        bounding_aspect = @user_width.to_f / height

        if bounding_aspect > max_aspect
          xres = max_width
          yres = (max_width * @user_height.to_f / @user_width).round
        else
          xres = (max_height * @user_width.to_f / @user_height).round
          yres = max_height
        end

        x_from = (@user_xmin || @xmin)..(@user_xmax || @xmax)
        y_from = (@user_ymax || @ymax)..(@user_ymin || @ymin) # Reverse Y to convert Cartesian to screen coordinates
        x_to = 0..xres
        y_to = 0..yres

        svg = <<-XML
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{xres} #{yres}" overflow="hidden" preserveAspectRatio="xMinYMin meet">
        <style>
          circle.cell {
            stroke: #bbb;
            fill: #222;
          }
          rect.neighbor {
            stroke: #aab;
            fill: #2727da;
            fill-opacity: 0.9;
          }
          polygon.delaunay {
            fill: none;
            stroke: #eee;
            stroke-width: 2px;
          }
          polygon.voronoi {
            fill: rgb(60,70,240);
            stroke: #bbb;
            stroke-width: 2px;
          }
          polygon.neighbor {
            fill: #6688ee;
            fill-opacity: 0.75;
            stroke: #4444bb;
            stroke-width: 3px;
            stroke-opacity: 0.9;
            stroke-dasharray: 5;
          }
        </style>
        XML

        {
          xres: xres,
          yres: yres,
          x_from: x_from,
          x_to: x_to,
          y_from: y_from,
          y_to: y_to,
          svg: svg,
        }
      end

      # Used internally.  Appends Delaunay triangles to the SVG in +svg_state+,
      # which should have been returned by #start_svg.
      def add_delaunay_svg(svg_state, include_reflections)
        if include_reflections != @reflect
          v2 = MB::Geometry::Voronoi.new(@cells.map(&:point), engine: @engine, reflect: include_reflections)
          v2.set_area_bounding_box(*area_bounding_box)
          triangles = v2.delaunay_triangles
        else
          triangles = delaunay_triangles
        end

        triangles = triangles.lazy.map { |t|
          t.points.lazy.sort.flat_map { |x, y|
            scale_svg_point(svg_state, x, y)
          }
        }.uniq

        triangles.each do |t|
          svg_state[:svg] << %Q{<polygon class="delaunay" points="#{t.join(' ')}" />\n}
        end
      end

      # Used internally. Appends Voronoi cells to the SVG in +svg_state+, which
      # should have been returned by #start_svg.  If +include_points+ is true,
      # then circles for each cell's point are grouped with the cell polygon,
      # so #add_points_svg can be skipped.  Reasons not to draw points here
      # include wanting to draw Delaunay triangulation or other visualizations
      # above the Voronoi cells but below the cell points.
      def add_voronoi_svg(svg_state, include_points)
        x_from = svg_state[:x_from]
        y_from = svg_state[:y_from]
        x_to = svg_state[:x_to]
        y_to = svg_state[:y_to]

        @cells.each_with_index do |c, idx|
          cx, cy = scale_svg_point(svg_state, c.x, c.y)

          cv = c.voronoi_vertices.map { |v| scale_svg_point(svg_state, *v.point) }.uniq.flatten

          r, g, b, a = c.color
          a ||= 1.0
          color = %Q{rgb(#{(r * 255).to_i}, #{(g * 255).to_i}, #{(b * 255).to_i})}

          svg_state[:svg] << <<-XML
          <g id="cell-#{idx}">
            <polygon class="voronoi" style="fill:#{color};fill-opacity:#{a};stroke-opacity:#{a}" points="#{cv.join(' ')}" />
          XML

          svg_state[:svg] << %Q{<circle class="cell" r="5" cx="#{cx}" cy="#{cy}" />\n} if include_points

          svg_state[:svg] << "</g>\n"
        end
      end

      # Used internally.  Adds and removes a natural-neighbor sampling point,
      # then adds that point's location, cell boundary, and proportional
      # neighbor connections to the SVG.
      def add_neighbor_svg(svg_state, x, y)
        nx, ny = scale_svg_point(svg_state, x, y)
        neighbors = natural_neighbors(x, y)

        neighbor_svg = %Q{<g>\n}

        boundary = neighbors[:vertices].flat_map { |p| scale_svg_point(svg_state, *p) }
        neighbor_svg << %Q{<polygon class="neighbor" points="#{boundary.join(' ')}" />\n}

        neighbors[:weights].each do |idx, weight|
          cx, cy = scale_svg_point(svg_state, *@cells[idx].point)

          binding.pry if weight < 0 # XXX
          stroke = MB::M.scale(Math.sqrt(weight), 0.0..1.0, 3.0..10.0) rescue binding.pry # XXX
          alpha = MB::M.scale(weight, 0.0..1.0, 0.1..0.9)
          color = %Q{rgb(255, 255, 255)}
          style = %Q{stroke:#{color}; stroke-opacity: #{alpha}; stroke-width: #{stroke}}

          neighbor_svg << %Q{<line class="neighbor" style="#{style}" x1="#{nx}" y1="#{ny}" x2="#{cx}" y2="#{cy}" />\n}
        end

        neighbor_svg << %Q{<rect class="neighbor" x="#{nx - 5}" y="#{ny - 5}" width="10" height="10" />\n}

        neighbor_svg << %Q{</g>\n}

        svg_state[:svg] << neighbor_svg
      end

      # Used internally.  Adds circles for each cell point.
      def add_points_svg(svg_state)
        @cells.each_with_index do |c, idx|
          cx, cy = scale_svg_point(svg_state, c.x, c.y)
          svg_state[:svg] << %Q{<circle class="cell" r="5" cx="#{cx}" cy="#{cy}" />\n}
        end
      end

      # Used internally.  Scales a point from Voronoi space to SVG space.
      def scale_svg_point(svg_state, x, y)
        x_from = svg_state[:x_from]
        y_from = svg_state[:y_from]
        x_to = svg_state[:x_to]
        y_to = svg_state[:y_to]

        cx = MB::M.scale(x, x_from, x_to).round(4)
        cy = MB::M.scale(y, y_from, y_to).round(4)

        return cx, cy
      end

      # Used internally.  Adds the SVG end tag.
      def end_svg(svg_state)
        # TODO Add some kind of label or title or annotation?
        svg_state[:svg] << '</svg>'
      end

      # Used internally.  Writes SVG from +svg_state+ to +filename+, stripping
      # whitespace from lines.
      def write_svg(svg_state, filename)
        raise "SVG isn't finished" unless svg_state[:svg] =~ %r{</svg>\s*\z}

        File.write(filename, svg_state[:svg].lines.map(&:strip).join("\n"))
      end

      # Saves the Voronoi diagram to an SVG file.  Warning: the RubyVor SVG
      # generator sometimes draws infinite segments incorrectly for perfectly
      # symmetrical diagrams.  It also cannot save a two-point Voronoi diagram,
      # or a collinear diagram if reflect was set to false in the constructor.
      # This includes reflected copies of the diagram if reflect is true.
      def save_rubyvor_svg(filename, voronoi_diagram: true, triangulation: true)
        RubyVor::Visualizer.make_svg(
          rubyvor,
          name: filename,
          voronoi_diagram: voronoi_diagram,
          triangulation: triangulation
        )
      end

      # Saves the Delaunay triangulation to an SVG file, with the viewport set
      # to the area_bounding_box.  The SVG viewport will be max_width pixels
      # wide or max_height pixels high, depending on the aspect ratio of the
      # area bounding box.
      def save_delaunay_svg(filename, max_width: 1000, max_height: 1000, reflect_delaunay: false)
        save_svg(
          filename,
          max_width: max_width,
          max_height: max_height,
          voronoi: false,
          delaunay: true,
          reflect_delaunay: reflect_delaunay
        )
      end

      # Saves a color-filled Voronoi diagram, cropped to the area_bounding_box,
      # to the given +filename+.  The largest dimension of the area bounding
      # box is normalized to +size+ pixels.
      def save_svg(filename, max_width: 1000, max_height: 1000, voronoi: true, delaunay: false, reflect_delaunay: false, points: true)
        svg = start_svg(max_width, max_height)
        add_voronoi_svg(svg, points && !delaunay) if voronoi # points added later if delaunay is true or voronoi false
        add_delaunay_svg(svg, reflect_delaunay) if delaunay
        add_points_svg(svg) if points && (delaunay || !voronoi)
        end_svg(svg)
        write_svg(svg, filename)
      end

      # Saves a color-filled Voronoi diagram with the given natural neighbor
      # sample point(s) and resulting cell(s) overlaid.  The drawing area of the
      # SVG is not expanded to include an out-of-bounds point.
      #
      # Note: temporarily modifies the list of points.
      def save_neighbor_svg(filename, *sample_points, max_width: 1000, max_height: 1000)
        svg = start_svg(max_width, max_height)
        add_voronoi_svg(svg, false)

        sample_points.each do |x, y|
          raise 'Each sample point must be two-dimensional' unless x && y
          add_neighbor_svg(svg, x, y)
        end

        add_points_svg(svg)

        end_svg(svg)
        write_svg(svg, filename)
      end
    end
  end
end
