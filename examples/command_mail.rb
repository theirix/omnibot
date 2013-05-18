#!/usr/bin/env ruby
# encoding: utf-8
# You can specify this script in ~/.forward for mail forwarding
IO.popen('omnisend','w') do |io|
	IO.new(STDIN.fileno, 'r:UTF-8').each { |s| io.write s }
end
