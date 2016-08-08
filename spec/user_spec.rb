require 'rspec'
require 'main'

describe User do
  let(:user) { User.new({ 'fname' => 'test', 'lname' => 'user'})}
  describe("::find_by_name") do
    it "returns nil when names do not exist" do
      expect(User.find_by_name('test', 'user')).to be_a_kind_of(NilClass)
      user.delete
    end

    it "returns a user when names exist" do
      user.save
      expect(User.find_by_name('test', 'user')).to be_a_kind_of(User)
      user.delete
    end
  end
  
  describe "#average_karma" do
    it "returns a number" do
      expect(user.average_karma).to be_a_kind_of(Float)
    end
  end
end
