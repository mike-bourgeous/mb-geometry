#!/usr/bin/env ruby

STDERR.puts "Changing $0 to #{ARGV[0]}"
$0 = ARGV.shift
require_relative 'simplecov_helper'
require File.expand_path($0, '.')
