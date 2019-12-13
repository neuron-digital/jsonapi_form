require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/object/deep_dup'
require 'active_support/hash_with_indifferent_access'
require 'active_support/i18n'
require 'active_model'

require 'jsonapi_form/version'
require 'jsonapi_form/errors'
require 'jsonapi_form/base'

I18n.load_path << File.dirname(__FILE__) + '/../locale/locale.yml'
