require File.expand_path('../../../spec_helper', __FILE__)

describe OAuth2::Grant::Implicit do

  before :all do
    @host           = 'example.com'
    @client_id      = 's6BhdRkqt3'
    @client_secret  = 'SplxlOBeZQQYbYS6WxSbIA'
    @client = OAuth2::Client.new(@host, @client_id, @client_secret)
  end

  subject do
    OAuth2::Grant::Implicit.new(@client)
  end

  describe "#response_type" do
    it "returns response type" do
      expect(subject.response_type).to eq 'token'
    end
  end

  describe "#token_url" do
    it "generates a token path using the given parameters" do

    end
  end

  describe "#get_token" do
    it "gets access token" do
      subject.should_receive(:make_request).with(:post, "/oauth2/token", {:params=>{:grant_type=>"refresh_token", :refresh_token=>"2YotnFZFEjr1zCsicMWpAA"}})
      subject.get_token(:params => {:scope => 'xyz', :state => 'abc xyz'})
    end
  end
end