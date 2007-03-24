#!/usr/bin/env ruby
# This is based off of Sam Ruby's xml_filetest.rb
# I've adapted it for feedparser.rb
# http://intertwingly.net/blog/2005/10/30/Testing-FeedTools-Dynamically/

# NOTE FIXME Mongrel doesn't like many of the encoding/x80*.xml tests. I don't know why
# I haven't figured out yet how to make the Time methods "rollover" on 25 hours, 61 minutes, etc.
require 'test/unit'
require '../lib/feedparser'

begin 
  require 'rubygems'
  gem 'mongrel'
  require 'mongrel'
rescue => details
  STDERR.puts "Whoops, had an error with loading mongrel as a gem. Trying just 'require'. Mongrel is required for testing."
  require 'mongrel'
end


$PORT = 8097 # Not configurable, hard coded in the xml files

def translate_data(data)
  if data[0..3] == "\x4c\x6f\xa7\x94"
    # EBCDIC
    data = _ebcdic_to_ascii(data)
  elsif data[0..3] == "\x00\x3c\x00\x3f"
    # UTF-16BE
    data = uconvert(data, 'utf-16be', 'utf-8')
  elsif data.size >= 4 and data[0..1] == "\xfe\xff" and data[2..3] != "\x00\x00"
    # UTF-16BE with BOM
    data = uconvert(data[2..-1], 'utf-16be', 'utf-8')
  elsif data[0..3] == "\x3c\x00\x3f\x00"
    # UTF-16LE
    data = uconvert(data, 'utf-16le', 'utf-8')
  elsif data.size >=4 and data[0..1] == "\xff\xfe" and data[2..3] != "\x00\x00"
    # UTF-16LE with BOM
    data = uconvert(data[2..-1], 'utf-16le', 'utf-8')
  elsif data[0..3] == "\x00\x00\x00\x3c"
    # UTF-32BE
    data = uconvert(data, 'utf-32be', 'utf-8')
  elsif data[0..3] == "\x3c\x00\x00\x00"
    # UTF-32LE
    data = uconvert(data, 'utf-32le', 'utf-8')
  elsif data[0..3] == "\x00\x00\xfe\xff"
    # UTF-32BE with BOM
    data = uconvert(data[4..-1], 'utf-32BE', 'utf-8')
  elsif data[0..3] == "\xff\xfe\x00\x00"
    # UTF-32LE with BOM
    data = uconvert(data[4..-1], 'utf-32LE', 'utf-8')
  elsif data[0..2] == "\xef\xbb\xbf"
    # UTF-8 with BOM
    data = data[3..-1]
  else
    # ASCII-compatible
  end
  return data
end

def scrape_headers(xmlfile)
  # Called by the server
  xm = open(xmlfile)
  data = xm.read
  htaccess = File.dirname(xmlfile)+"/.htaccess"
  xml_headers = {}
  server_headers = {}
  the_type = nil
  if File.exists? htaccess
    fn = xm.path.split(File::Separator)[-1] # I can't find the right method for this
    ht_file = open(htaccess)
    type_match = ht_file.read.match(/^\s*<Files\s+#{fn}>\s*\n\s*AddType\s+(.*?)\s+.xml/m)
    the_type = type_match[1].strip.gsub(/^("|')/,'').gsub(/("|')$/,'').strip if type_match and type_match[1]
    if type_match and the_type
      #content_type, charset = type_match[1].split(';')
      server_headers["Content-Type"] = the_type
    end
  end
  data = translate_data(data)
  da = data.scan /^Header:\s*([^:]+):(.+)\s$/
  unless da.nil? or da.empty?
    da.flatten!
    da.each{|e| e.strip!;e.gsub!(/(Content-type|content-type|content-Type)/, "Content-Type")}
    xml_headers = Hash[*da] # Asterisk magic!
  end
  return xml_headers.merge(server_headers)
end

def scrape_assertion_strings(xmlfile)
  # Called by the testing client
  data = open(xmlfile).read
  data = translate_data(data)
  test = data.scan /Description:\s*(.*?)\s*Expect:\s*(.*)\s*-->/
  description, evalString = test.first.map{ |s| s.strip }

  # Here we translate the expected values in Python to Ruby
  evalString.gsub!(/\bu'(.*?)'/) do |m|     
    esc = $1.to_s.dup
    esc.gsub!(/\\u([0-9a-fA-F]{4})/){ |m| [$1.hex].pack('U*') }
    " '"+esc+"'"
  end 
  evalString.gsub!(/\bu"(.*?)"/) do |m|
    esc = $1.to_s.dup
    esc.gsub!(/\\u([0-9a-fA-F]{4})/){ |m| [$1.hex].pack('U*') }
    " \""+esc+"\""
  end
  # The above does the following:               u'string' => 'string'
  #                                             u'ba\u20acha' => 'ba€ha' # Same for double quoted strings

  evalString.gsub!(/\\x([0-9a-fA-F]{2})/){ |m| [$1.hex].pack('U*') } # "ba\xa3la" => "ba£la"
  evalString.gsub! /'\s*:\s+/, "' => "        # {'foo': 'bar'} => {'foo' => 'bar'}
  evalString.gsub! /"\s*:\s+/, "\" => "       # {"foo": 'bar'} => {"foo" => 'bar'}
  evalString.gsub! /\=\s*\((.*?)\)/, '= [\1]' # = (2004, 12, 4) => = [2004, 12, 4]
  evalString.gsub!(/"""(.*?)"""/) do          # """<a b="foo">""" => "<a b="foo">"
    "\""+$1.gsub!(/"/,"\\\"")+"\"" # haha, ugly!
  end
  evalString.gsub! /(\w|\])\s*\=\= 0\s*$/, '\1 == false'   # ] == 0 => ] == false
  evalString.gsub! /(\w|\])\s*\=\= 1\s*$/, '\1 == true'    # ] == 1 => ] == true
  evalString.gsub! /len\((.*?)\)\s*\=\=\s*(\d{1,3})/, '\1.length == \2' # len(ary) == 1 => ary.length == 1
  evalString.gsub! /None/, "nil" # None => nil # well, duh
  return description, evalString
end

class FeedParserTestRequestHandler < Mongrel::DirHandler 
  def process(request, response)
    req_method = request.params[Mongrel::Const::REQUEST_METHOD] || Mongrel::Const::GET
    req_path = can_serve request.params[Mongrel::Const::PATH_INFO]
    if not req_path
      # not found, return a 404
      response.start(404) do |head, out|
        out << "File not found"
      end
    else
      begin
        if File.directory? req_path
          send_dir_listing(request.params[Mongrel::Const::REQUEST_URI], req_path, response)
        elsif req_method == Mongrel::Const::HEAD
          response.start do |head,out| 
            xml_head = scrape_headers(req_path)
            xml_head.each_key{|k| head[k] = xml_head[k] }
          end

          send_file(req_path, request, response, true)
        elsif req_method == Mongrel::Const::GET
          response.start do |head,out| 
            xml_head = scrape_headers(req_path)
            xml_head.each_key{|k| head[k] = xml_head[k] }
          end

          send_file(req_path, request, response, false)
        else
          response.start(403) {|head,out| out.write(ONLY_HEAD_GET) }
        end
      rescue => details
        STDERR.puts "Error sending file #{req_path}: #{details}"
      end
    end
  end
end


class XMLTests < Test::Unit::TestCase
  # Empty, but here for clarity
  def setup
  end
  def teardown
  end
end

# default methods to be public
XMLTests.send(:public)
# add one unit test for each file
Dir['**/*.xml'].each do |xmlfile| # Test a subset
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
server.register("/", FeedParserTestRequestHandler.new("."))
server.run
