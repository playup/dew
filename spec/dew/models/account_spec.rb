require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

describe Account do

  describe :initialize do
    it "should look for the named account file in the ~/.dew/accounts dir" do
      name = 'a_development_name'
      File.should_receive(:read).with("#{ENV['HOME']}/.dew/accounts/#{name}.yaml").and_return("---")
      Account.read(name)
    end
  end

  describe "parsing yaml" do
    before :each do
      yaml =
        "aws:
          user_id: 9999-3333-2222
          access_key_id: foo
          secret_access_key: bar"

      File.stub(:read).and_return(yaml)
      @account = Account.read('foo')
    end

    it "should have a user_id stripped of dashes" do
      @account.aws_user_id.should == '999933332222'
    end

    it "should have an aws access key id" do
      @account.aws_access_key_id.should == 'foo'
    end

    it "should have an aws secret access key" do
      @account.aws_secret_access_key.should == 'bar'
    end
  end
  
  describe ".user_ids" do
    it "should return the user_ids of each account file in config/accounts" do
      Dir.should_receive(:[]).with("#{ENV['HOME']}/.dew/accounts/*.yaml").and_return(["accounts/file1.yaml", "accounts/file2.yaml"])
      Account.should_receive(:read).with("file1").and_return(double('account', :aws_user_id => 'id1'))
      Account.should_receive(:read).with("file2").and_return(double('account', :aws_user_id => 'id2'))
      Account.user_ids.sort.should == ['id1', 'id2']
    end
  end

end
