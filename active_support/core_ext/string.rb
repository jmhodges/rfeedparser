require File.dirname(__FILE__) + '/string/unicode'
require File.dirname(__FILE__) + '/string/access'
require File.dirname(__FILE__) + '/string/conversions'
require File.dirname(__FILE__) + '/string/iterators'

class String #:nodoc:
  include ActiveSupport::CoreExtensions::String::Unicode
  include ActiveSupport::CoreExtensions::String::Access
  include ActiveSupport::CoreExtensions::String::Conversions
  include ActiveSupport::CoreExtensions::String::Iterators
end
