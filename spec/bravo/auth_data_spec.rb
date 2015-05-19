require 'spec_helper'

module Bravo
  describe AuthData do
    context 'when new credentials are necessary' do
      before do
        allow(described_class).to receive(:currently_authorized?).and_return(false)
      end

      it 'creates constants for todays data' do
        expect(Wsaa).to receive(:login)
        Bravo::AuthData.create
      end
    end
  end
end
