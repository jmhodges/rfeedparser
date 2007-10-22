#!/usr/bin/env ruby
# This is based off of Sam Ruby's xml_filetest.rb
# I've adapted it for rfeedparser
# http://intertwingly.net/blog/2005/10/30/Testing-FeedTools-Dynamically/

require File.join(File.dirname(__FILE__),'rfeedparser_test_helper')

# default methods to be public
XMLTests.send(:public)
# add one unit test for each file
Dir['**/*.xml'].each do |xmlfile| 
  #Dir['tests/**/*.xml'].each do |xmlfile|
  methname = "tests_"+xmlfile.gsub('/','_').sub('.xml','')
  XMLTests.send(:define_method, methname) {

    options = {}
    options[:compatible] = true 
    # This keeps compatibility with 4.1 feedparser tests (i.e. no
    # smart stripping of styles).  This is not (yet) required, as 
    # rfeedparser is compatible by default.


    # Evaluate feed
    
    fp = FeedParser.parse("http://127.0.0.1:#{$PORT}/#{xmlfile}", options) 
    # I should point out that the 'compatible' arg is not necessary, 
    # but probably will be in the future if we decide to change the default.

    description, evalString = scrape_assertion_strings(xmlfile)
    assert fp.instance_eval(evalString), description.inspect
  }
end
# Start up the mongrel server and tell it how to send the tests
server = Mongrel::HttpServer.new("0.0.0.0",$PORT)
Mongrel::DirHandler::add_mime_type('.xml','application/xml')
Mongrel::DirHandler::add_mime_type('.xml_redirect','application/xml')
server.register("/", FeedParserTestRequestHandler.new("."))
server.run
