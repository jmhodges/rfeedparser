# Stripped with few changes from Ruby on Rails
module Multibyte
  DEFAULT_NORMALIZATION_FORM = :kc
  NORMALIZATIONS_FORMS = [:c, :kc, :d, :kd]
  UNICODE_VERSION = '5.0.0'
end

require 'multibyte/chars'
