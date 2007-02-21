#!/usr/bin/env ruby
# This is based off of Sam Ruby's xml_filetest.rb
# I've adapted it for feedparser.rb
# http://intertwingly.net/blog/2005/10/30/Testing-FeedTools-Dynamically/

require 'test/unit'
require 'feedparser'

class XMLTests < Test::Unit::TestCase
  def setup
  end

  def teardown
  end
end

# default methods to be public
XMLTests.send(:public)

# add one unit test for each file
Dir['tests/wellformed/atom10/*.xml'].each do |xmlfile|
#Dir['tests/**/*.xml'].each do |xmlfile|
  XMLTests.send(:define_method, xmlfile.gsub('/','_').sub('.xml','')) {
    # extract description, evalString
    feed_data = open(xmlfile) 
    test = feed_data.read.scan /Description:\s*(.*?)\s*Expect:\s*(.*)\s*-->/
    feed_data.close
    raise RuntimeError, "can't parse #{xmlfile}" if test.empty?
    description, evalString = test.first.map{ |s| s.strip }

    # Python to Ruby
    # with a few additions by me
    evalString.gsub! /\bu('.*?')/, '\1'    # u'string' => 'string'
    evalString.gsub! /\bu(".*?")/, '\1'    # u"string" => "string"
    evalString.gsub! /\['(\w+)'\]/, '.\1'  # ['x'] => .x
    evalString.gsub! /'\s*:\s+/, "' => "   # {'foo': 'bar'} => {'foo' => 'bar'}
                                           # {'foo' : 'bar'} => {'foo' => 'bar'}
    evalString.gsub! /"\s*:\s+/, "\" => "  # {"foo": 'bar'} => {"foo" => 'bar'}

    # Evaluate feed
    fp = FeedParser.parse(xmlfile, compatible=true) 
    # NOTE If we renamed the 'fp' variable to 'feed', the evalString will 
    # return errors when it contains a reference to the feed method.  
    # Also, I should point out that the 'compatible' arg is not necessary, 
    # but probably will be in the future if we decide to change the default.
    assert fp.instance_eval(evalString, description.inspect)
  }
end
