# frozen_string_literal: true

require 'yard'
require 'rbs'
require_relative 'yard_inline_rbs/rbs_type_formatter'
require_relative 'yard_inline_rbs/rbs_description'
require_relative 'yard_inline_rbs/rbs_function_types'
require_relative 'yard_inline_rbs/parse_result'
require_relative 'yard_inline_rbs/type_parser'
require_relative 'yard_inline_rbs/inline_annotations'
require_relative 'yard_inline_rbs/rbs_comment_parser'
require_relative 'yard_inline_rbs/parameter_names'
require_relative 'yard_inline_rbs/annotation_warnings'
require_relative 'yard_inline_rbs/declaration_source'
require_relative 'yard_inline_rbs/inline_types'
require_relative 'yard_inline_rbs/result_applier'
require_relative 'yard_inline_rbs/object_tags'
require_relative 'yard_inline_rbs/tag_injector'
require_relative 'yard_inline_rbs/overload_text'
require_relative 'yard_inline_rbs/member_tags'
require_relative 'yard_inline_rbs/rbs_file_tags'
require_relative 'yard_inline_rbs/rbs_handler_patches'
require_relative 'yard_inline_rbs/plugin'

# YARD plugin that turns inline RBS annotations into `@param`, `@return`, `@yield` and
# `@yieldreturn` tags, so the documented types are the ones Steep checks.
module YardInlineRbs
  # @rbs (String message) -> void
  def self.warn(message)
    YARD::Logger.instance.warn("[yard-inline-rbs] #{message}")
  end
end
