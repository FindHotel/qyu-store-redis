RSpec.describe Qyu::Store::Redis do
  it "has a version number" do
    expect(Qyu::Store::Redis::VERSION).not_to be nil
  end

  context 'fake logger' do
    before { Qyu.logger = nil }

    it { expect(Qyu.logger.nil?).to be false }
  end
end
