# frozen_string_literal: true

require "pakyow/errors"
require "pakyow/verifier"

module Pakyow
  module Verification
    def self.included(base)
      base.extend(ClassMethods)
    end

    def verify(&block)
      object_to_verify = public_send(self.class.object_name_to_verify)

      verifier = Class.new(Verifier)
      verifier.instance_exec(&block)

      verifier_instance = verifier.new(object_to_verify, context: self)
      unless verifier_instance.verify?
        error = InvalidData.new_with_message(:verification)
        error.context = {
          object: object_to_verify,
          verifier: verifier_instance
        }

        raise error
      end
    end

    module ClassMethods
      attr_reader :object_name_to_verify

      def inherited(subclass)
        super

        subclass.instance_variable_set(:@object_name_to_verify, @object_name_to_verify)
      end

      def verifies(object)
        @object_name_to_verify = object
      end
    end
  end
end
