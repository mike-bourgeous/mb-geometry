require 'shellwords'
require 'fileutils'

require 'mb-util'

RSpec.describe('bin/voronoi_transitions.rb') do
  let(:tmpdir) { File.expand_path('../../tmp', __dir__) }

  before(:each) do
    Dir[File.join(tmpdir, 'test*.svg')].each do |f|
      File.unlink(f)
    end
    FileUtils.mkdir_p(tmpdir)
  end

  after(:each) do
    Dir[File.join(tmpdir, 'test*.svg')].each do |f|
      File.unlink(f)
    end
  end

  it 'generates the expected number of frames' do
    text = `bin/voronoi_transitions.rb #{tmpdir.shellescape}/test.svg test_data/3gon.yml 30 40 test_data/square.yml 50 55`
    result = $?

    expect(result).to be_success
    expect(MB::U.remove_ansi(text)).to match(/ 175 /)
    expect(Dir[File.join(tmpdir, 'test*.svg')].length).to eq(175)
  end
end
