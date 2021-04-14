require 'spec_helper'

module Resque
  module Restriction
    RSpec.describe Config do
      it 'has a default of nil for max_queue_peek (disabled)' do
        expect(Restriction.config.max_queue_peek('restriction_queue1')).to be_nil
      end

      it 'can be configured with new values' do
        Restriction.configure do |config|
          config.max_queue_peek = 50
        end
        expect(Restriction.config.max_queue_peek('restriction_queue1')).to eq(50)
      end

      it 'errors when given an integer less than 1' do
        expect {
          Restriction.configure do |config|
            config.max_queue_peek = 0
          end
        }.to raise_error(ArgumentError, "max_queue_peek should be either nil or an Integer greater than 0 but 0 was provided")
      end

      it 'errors when given an non-integer' do
        expect {
          Restriction.configure do |config|
            config.max_queue_peek = "abcd"
          end
        }.to raise_error(ArgumentError, 'max_queue_peek should be either nil or an Integer greater than 0 but "abcd" was provided')
      end

      it 'can be configured with a lambda' do
        Restriction.configure do |config|
          sizes = {
            'foo' => 10,
            'bar' => 100
          }
          config.max_queue_peek = -> queue { sizes[queue] || 25 }
        end
        expect(Restriction.config.max_queue_peek('foo')).to eq(10)
        expect(Restriction.config.max_queue_peek('bar')).to eq(100)
        expect(Restriction.config.max_queue_peek('baz')).to eq(25)
      end
    end
  end
end
