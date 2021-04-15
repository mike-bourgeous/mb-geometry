RSpec.describe('bin/triangulate.rb') do  
  cmd = File.expand_path('../../bin/triangulate.rb', __dir__)
  data_path = File.expand_path('../../test_data', __dir__)
  all_test_files = Dir[File.join(data_path, '*.*')]

  it "can parse all files from test_data/" do
    expect(system("#{cmd.shellescape} #{all_test_files.map(&:shellescape).join(' ')} > /dev/null")).to eq(true)
  end

  it 'fails to parse an invalid file' do
    expect(system("#{cmd.shellescape} #{cmd.shellescape} > /dev/null")).to eq(false)
  end

  pending 'Test with debug, fast, and rubyvor (from Voronoi) engines for triangulation'
end
