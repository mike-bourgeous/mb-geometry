#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

require 'json'
require 'benchmark'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/delaunay'

Pry.pry
