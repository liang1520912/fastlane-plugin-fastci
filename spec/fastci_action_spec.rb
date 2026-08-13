require 'spec_helper'

describe Fastlane::Actions::AppStoreResourcesAction do
  describe '.description' do
    it 'describes App Store Connect resource publishing' do
      expect(described_class.description).to include('metadata')
      expect(described_class.description).to include('截图')
    end
  end
end
