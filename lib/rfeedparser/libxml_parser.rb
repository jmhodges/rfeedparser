require 'xml/libxml'

module FeedParser
 module LibXml
   class StrictFeedParser
     attr_reader :handler

     def initialize(baseuri, baselang)
       @handler = StrictFeedParserHandler.new(baseuri, baselang, 'utf-8')
     end

     def parse(data)
       saxparser = XML::SaxParser.new
       saxparser.callbacks = @handler
       saxparser.string = data
       saxparser.parse
     end
   end

   class StrictFeedParserHandler
     include XML::SaxParser::Callbacks
     include FeedParserMixin

     attr_accessor :bozo, :entries, :feeddata, :exc
     def initialize(baseuri, baselang, encoding)
       $stderr << "trying StrictFeedParser\n" if $debug
       startup(baseuri, baselang, encoding)
       @bozo = false
       @exc = nil
       super()
     end

     #def getPos
       #[@locator.getSystemId, @locator.getLineNumber]
     #end

     def getAttrs(attrs)
       ret = []
       for i in 0..attrs.getLength
   ret.push([attrs.getName(i), attrs.getValue(i)])
       end
       ret
     end

     #def setDocumentLocator(loc)
       #@locator = loc
     #end

     #def startDoctypeDecl(name, pub_sys, long_name, uri)
       ##Nothing is done here. What could we do that is neat and useful?
     #end

     #def startNamespaceDecl(prefix, uri)
       #trackNamespace(prefix, uri)
     #end

     #def endNamespaceDecl(prefix)
     #end

     def on_start_element(name, attrs)
       name =~ /^(([^;]*);)?(.+)$/ # Snag namespaceuri from name
   namespaceuri = ($2 || '').downcase
       name = $3
       if /backend\.userland\.com\/rss/ =~ namespaceuri
   # match any backend.userland.com namespace
   namespaceuri = 'http://backend.userland.com/rss'
       end
       prefix = @matchnamespaces[namespaceuri]
       # No need to raise UndeclaredNamespace, Expat does that for us with
       "unbound prefix (XMLParserError)"
       if prefix and not prefix.empty?
   name = prefix + ':' + name
       end
       name.downcase!
       unknown_starttag(name, attrs)
     end

     def on_characters(text)
       handle_data(text)
     end

     def on_cdata_block(content)
       handle_data(content)
     end

     def on_end_element(name)
       name =~ /^(([^;]*);)?(.+)$/ # Snag namespaceuri from name
   namespaceuri = ($2 || '').downcase
       prefix = @matchnamespaces[namespaceuri]
       if prefix and not prefix.empty?
   localname = prefix + ':' + name
       end
       name.downcase!
       unknown_endtag(name)
     end

     def on_comment(comment)
       handle_comment(comment)
     end

     #def entityDecl(*foo)
     #end

     #def unparsedEntityDecl(*foo)
     #end

     def on_parser_error(exc)
       @bozo = true
       @exc = exc
       raise exc
     end

     def on_parser_fatal_error(exc)
       # Lib xml doesn't seem to call this??
       on_parser_error(exc)
       raise exc
     end
   end
 end
end
