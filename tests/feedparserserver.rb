#!/usr/bin/ruby
# This is the same server code that runs in feedparsertest.rb, but split
# off so that we can fully check each test individually (i.e. get the HTTP
# headers right).
require 'rubygems'
gem 'mongrel'
require 'mongrel'
require '../lib/feedparser'
$PORT = 8097
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
  elsif data[0..3] == "\xef\xfe\x00\x00"
    # UTF-32LE with BOM
    data = uconvert(data[4..-1], 'utf-32le', 'utf-8')
  elsif data[0..2] == "\xef\xbb\xbf"
    # UTF-8 with BOM
    data = data[3..-1]
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
            xml_head = scape_headers(req_path)
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
        STDERR.puts "MON Error sending file #{req_path}: #{details}"
      end
    end
  end
end

# Start up the mongrel server and tell it how to send the tests
server = Mongrel::HttpServer.new("0.0.0.0", $PORT)
Mongrel::DirHandler::add_mime_type('.xml','application/xml')
server.register("/", FeedParserTestRequestHandler.new('.'))
server.run.join
