require 'forwardable'

module Epp
  class Response
    class Result
      extend Forwardable

      attr_reader :code

      delegate(description: :code)

      def initialize(code:)
        @code = code
      end
    end
  end
end
