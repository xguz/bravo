require 'spec_helper'

module Bravo
  describe AuthData do
    context 'when new credentials are necessary' do
      before do
        allow(described_class).to receive(:authorized_data?).and_return(false)
      end

      it 'creates constants for todays data' do
        expect(Bravo.constants).not_to include(:TOKEN, :SIGN)

        Bravo::AuthData.create

        expect(Bravo.constants).to include(:TOKEN, :SIGN)
      end
    end
  end
end
