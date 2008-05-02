# FIXME line 5 maps to line 171 in saxdriver.rb. note that there is no return 
# in the original
class XML::Parser::SAXDriver
   def openInputStream(stream)
      if stream.getByteStream
        return stream
      else stream.getSystemId
        url = URL.new(stream.getSystemId)
        if url.scheme == 'file' && url.login == 'localhost'
          s = open(url.urlpath)
          stream.setByteStream(s)
          return stream
        end
      end
      return nil
    end
end
    