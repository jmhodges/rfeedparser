#!/usr/bin/ruby

module URI
  # NOTE I wish I didn't have to open this module up,but I cannot find a 
  # better way of accessing all of the instance methods of the URI module. I \
  # may just be an idiot.
  def self.split(uri)
    case uri
    when ''
      # null uri

    when ABS_URI
      scheme, opaque, userinfo, host, port, 
	registry, path, query, fragment = $~[1..-1]

      # URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]

      # absoluteURI   = scheme ":" ( hier_part | opaque_part )
      # hier_part     = ( net_path | abs_path ) [ "?" query ]
      # opaque_part   = uric_no_slash *uric

      # abs_path      = "/"  path_segments
      # net_path      = "//" authority [ abs_path ]

      # authority     = server | reg_name
      # server        = [ [ userinfo "@" ] hostport ]

      if !scheme
	raise InvalidURIError, 
	  "bad URI(absolute but no scheme): #{uri}"
      end
      if !opaque && (!path && (!host && !registry))
	raise InvalidURIError,
	  "bad URI(absolute but no path): #{uri}" 
      end

    when REL_URI
      scheme = nil
      opaque = nil

      userinfo, host, port, registry, 
	rel_segment, abs_path, query, fragment = $~[1..-1]
      if rel_segment && abs_path
	path = rel_segment + abs_path
      elsif rel_segment
	path = rel_segment
      elsif abs_path
	path = abs_path
      end

      # URI-reference = [ absoluteURI | relativeURI ] [ "#" fragment ]

      # relativeURI   = ( net_path | abs_path | rel_path ) [ "?" query ]

      # net_path      = "//" authority [ abs_path ]
      # abs_path      = "/"  path_segments
      # rel_path      = rel_segment [ abs_path ]

      # authority     = server | reg_name
      # server        = [ [ userinfo "@" ] hostport ]

    else
      #	NOTE this is the only part of the code that differs from the "clean" 
      #	URI module.
      return [nil,nil,uri,nil,nil,nil,nil,nil,nil]
    end

    path = '' if !path && !opaque # (see RFC2396 Section 5.2)
    ret = [
      scheme, 
      userinfo, host, port,         # X
      registry,                        # X
      path,                         # Y
      opaque,                        # Y
      query,
      fragment
    ]
    return ret
  end
end

def urljoin(base, uri)
  urifixer = /^([A-Za-z][A-Za-z0-9+-.]*:\/\/)(\/*)(.*?)/u
  uri = uri.sub(urifixer, '\1\3') 
  begin
    return URI.join(base, uri).to_s 
  rescue URI::BadURIError => e
    if URI.parse(base).relative? 
      return URI::parse(uri).to_s
    end
  end
end

