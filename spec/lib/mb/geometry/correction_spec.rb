RSpec.describe(MB::Geometry::Correction) do
  # First four input and output points are used to test initializing a
  # correction from four points.  Remaining points are used as additional test
  # cases.
  test_cases = [
    {
      name: 'simple scaling in X',
      in_points: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
        [0.5, -1],
        [3.5, -1],
        [0.5, 0],
        [3.5, 0],
        [0.5, 1],
        [3.5, 1],
      ],
      out_points: [
        [-2, -1],
        [-2, 1],
        [2, -1],
        [2, 1],
        [1, -1],
        [7, -1],
        [1, 0],
        [7, 0],
        [1, 1],
        [7, 1],
      ],
      constants: [
        2, 0, 0,
        0, 1, 0
      ],
    },
    {
      name: 'simple scaling in Y',
      in_points: [
        [-1, -1],
        [1, -1],
        [-1, 1],
        [1, 1],
        [-1, 0.5],
        [-1, 3.5],
        [0, 0.5],
        [0, 3.5],
        [1, 0.5],
        [1, 3.5],
      ],
      out_points: [
        [-1, -2],
        [1, -2],
        [-1, 2],
        [1, 2],
        [-1, 1],
        [-1, 7],
        [0, 1],
        [0, 7],
        [1, 1],
        [1, 7],
      ],
      constants: [
        1, 0, 0,
        0, 2, 0
      ],
    },
    {
      name: 'simple translation in X',
      in_points: [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
        [0, -1],
        [10, -1],
        [0, 0],
        [10, 0],
        [0, 1],
        [10, 1],
      ],
      out_points: [
        [-1.5, -1],
        [-1.5, 1],
        [0.5, -1],
        [0.5, 1],
        [-0.5, -1],
        [9.5, -1],
        [-0.5, 0],
        [9.5, 0],
        [-0.5, 1],
        [9.5, 1],
      ],
      constants: [
        1, 0, -0.5,
        0, 1, 0
      ],
    },
    {
      name: 'simple translation in Y',
      in_points: [
        [-1, -1],
        [1, -1],
        [-1, 1],
        [1, 1],
        [-1, 0],
        [-1, 10],
        [0, 0],
        [0, 10],
        [1, 0],
        [1, 10],
      ],
      out_points: [
        [-1, -1.5],
        [1, -1.5],
        [-1, 0.5],
        [1, 0.5],
        [-1, -0.5],
        [-1, 9.5],
        [0, -0.5],
        [0, 9.5],
        [1, -0.5],
        [1, 9.5],
      ],
      constants: [
        1, 0, 0,
        0, 1, -0.5
      ],
    },
    {
      name: 'simple shear in X',
      in_points: [
        [-1, -1],
        [1, -1],
        [1, 1],
        [-1, 1],
        [-0.5, -0.5],
        [0, -0.5],
        [0.5, -0.5],
        [-0.5, 0],
        [0, 0],
        [0.5, 0],
        [-0.5, 0.5],
        [0, 0.5],
        [0.5, 0.5],
      ],
      out_points: [
        [-1.5, -1],
        [0.5, -1],
        [1.5, 1],
        [-0.5, 1],
        [-0.75, -0.5],
        [-0.25, -0.5],
        [0.25, -0.5],
        [-0.5, 0],
        [0, 0],
        [0.5, 0],
        [-0.25, 0.5],
        [0.25, 0.5],
        [0.75, 0.5],
      ],
      constants: [
        1, 0.5, 0,
        0, 1, 0
      ],
    },
    {
      name: 'simple shear in Y',
      in_points: [
        [-1, -1],
        [-1, 1],
        [1, 1],
        [1, -1],
        [-0.5, -0.5],
        [-0.5, 0],
        [-0.5, 0.5],
        [0, -0.5],
        [0, 0],
        [0, 0.5],
        [0.5, -0.5],
        [0.5, 0],
        [0.5, 0.5],
      ],
      out_points: [
        [-1, -1.5],
        [-1, 0.5],
        [1, 1.5],
        [1, -0.5],
        [-0.5, -0.75],
        [-0.5, -0.25],
        [-0.5, 0.25],
        [0, -0.5],
        [0, 0],
        [0, 0.5],
        [0.5, -0.25],
        [0.5, 0.25],
        [0.5, 0.75],
      ],
      constants: [
        1, 0.0, 0,
        0.5, 1, 0
      ],
    },
    {
      name: 'rotation by 45 degrees',
      in_points: [
        [-1, -1],
        [-1, 1],
        [1, 1],
        [1, -1],
        [-0.5, -0.5],
        [-0.5, 0],
        [-0.5, 0.5],
        [0, -0.5],
        [0, 0],
        [0, 0.5],
        [0.5, -0.5],
        [0.5, 0],
        [0.5, 0.5],
      ],
      out_points: [
        [0, -(2 ** 0.5)],
        [-(2 ** 0.5), 0],
        [0, 2 ** 0.5],
        [2 ** 0.5, 0],
        [0, -(0.5 ** 0.5)],
        [-0.5 * 0.5 ** 0.5, -0.5 * 0.5 ** 0.5],
        [-(0.5 ** 0.5), 0],
        [0.5 * 0.5 ** 0.5, -0.5 * 0.5 ** 0.5],
        [0, 0],
        [-0.5 * 0.5 ** 0.5, 0.5 * 0.5 ** 0.5],
        [0.5 ** 0.5, 0],
        [0.5 * 0.5 ** 0.5, 0.5 * 0.5 ** 0.5],
        [0, 0.5 ** 0.5],
      ],
      constants: [
        Math.cos(Math::PI / 4), -Math.sin(Math::PI / 4), 0,
        Math.sin(Math::PI / 4), Math.cos(Math::PI / 4), 0
      ],
    },
    {
      name: "large constants",
      in_points: [
        [-1, -1],
        [-1, 1],
        [1, 1],
        [1, -1],
        [-0.5, -0.5],
        [-0.5, 0],
        [-0.5, 0.5],
        [0, -0.5],
        [0, 0],
        [0, 0.5],
        [0.5, -0.5],
        [0.5, 0],
        [0.5, 0.5],
      ],
      out_points: [
        [-400, 400],
        [800, -800],
        [1800, -1800],
        [600, -600],
        [150.0, -150.0],
        [450.0, -450.0],
        [750.0, -750.0],
        [400.0, -400.0],
        [700, -700],
        [1000.0, -1000.0],
        [650.0, -650.0],
        [950.0, -950.0],
        [1250.0, -1250.0],
      ],
      constants: [
        500, 600, 700,
        -500, -600, -700
      ]
    },
  ]

  context 'when initialized from sample points' do
    test_cases.each do |t|
      context "for #{t[:name]}" do
        let(:c) { MB::Geometry::Correction.new(t[:in_points], t[:out_points]) }

        t[:in_points].each_with_index do |p, idx|
          q = t[:out_points][idx]
          it "maps #{p} to #{q}" do
            expect(MB::M.round(c.project(*p), 4)).to eq(MB::M.round(q, 4))
          end
        end

        it "has the expected value for constants ABCDEF" do
          expect(MB::M.round(c.constants, 4)).to eq(MB::M.round(t[:constants], 4))
        end
      end
    end
  end

  context 'when initialized from constants' do
    test_cases.each do |t|
      context "for #{t[:name]}" do
        let(:c) { MB::Geometry::Correction.new(t[:constants]) }

        t[:in_points].each_with_index do |p, idx|
          q = t[:out_points][idx]
          it "maps #{p} to #{q}" do
            expect(MB::M.round(c.project(*p), 6)).to eq(MB::M.round(q, 6))
          end
        end

        it "has the expected value for constants ABCDEF" do
          expect(MB::M.round(c.constants, 6)).to eq(MB::M.round(t[:constants], 6))
        end
      end
    end
  end

  describe '.rotation' do
    it 'can rotate by 0 degrees' do
      g = MB::Geometry::Correction.rotation(0)
      expect(g.constants).to eq([1, 0, 0, 0, 1, 0])
      expect(g.project(0, 1)).to eq([0, 1])
    end

    it 'can rotate by 180 degrees' do
      g = MB::Geometry::Correction.rotation(180.degrees)
      expect(g.constants).to eq([-1, 0, 0, 0, -1, 0])
      expect(g.project(0, 1)).to eq([0, -1])
    end

    it 'can rotate by 90 degrees' do
      g = MB::Geometry::Correction.rotation(90.degrees)
      expect(g.constants).to eq([0, -1, 0, 1, 0, 0])
      expect(g.project(0, 1)).to eq([-1, 0])
      expect(g.project(1, 0)).to eq([0, 1])
    end

    it 'can rotate by -60 degrees' do
      g = MB::Geometry::Correction.rotation(-60.degrees)
      expect(MB::M.round(g.constants, 5)).to eq(MB::M.round([0.5, 0.5 * 3 ** 0.5, 0, -0.5 * 3 ** 0.5, 0.5, 0], 5))
      expect(MB::M.round(g.project(0, 1), 5)).to eq(MB::M.round([0.5 * 3 ** 0.5, 0.5], 5))
      expect(MB::M.round(g.project(1, 0), 5)).to eq(MB::M.round([0.5, -0.5 * 3 ** 0.5], 5))
    end
  end
end
