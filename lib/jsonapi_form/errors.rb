# frozen_string_literal: true

module JSONAPIForm
  # @param error [ActiveModel::Errors] объект ошибок
  class InvalidStructure < StandardError
    attr_reader :error

    def initialize(error)
      @error = error

      super(@error.full_messages.join("\n"))
    end
  end
end
