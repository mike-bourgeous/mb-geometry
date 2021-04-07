#!/usr/bin/env ruby

require 'bundler/setup'

require 'pry'
require 'pry-byebug'

$:.unshift(File.join(__dir__, '..', 'lib'))
require 'mb/delaunay'

Pry.pry
