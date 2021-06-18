RSpec.describe('bin/triangulate.rb') do  
  cmd = File.expand_path('../../bin/triangulate.rb', __dir__)
  data_path = File.expand_path('../../test_data', __dir__)
  all_test_files = Dir[File.join(data_path, '*.*')]

  [:rubyvor, :delaunay, :delaunay_debug].each do |engine|
    it "can parse all files from test_data/ using #{engine}" do
      expect(test_system({ 'DELAUNAY_ENGINE' => engine.to_s }, "#{cmd.shellescape} #{all_test_files.map(&:shellescape).join(' ')} > /dev/null")).to eq(true)
    end

    it "fails to parse an invalid file using #{engine}" do
      output = `DELAUNAY_ENGINE=#{engine.to_s.shellescape} #{cmd.shellescape} #{cmd.shellescape} 2>&1 > /dev/null`
      result = $?
      expect(output).to match(/Unsupported extension/)
      expect(result).not_to be_success
    end
  end
end
