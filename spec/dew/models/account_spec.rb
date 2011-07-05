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
      File.stub(:read).and_return(yaml)
    end

    subject { Account.read('foo') }

    describe "with an aws section" do
      let (:yaml) {
        "aws:
          user_id: 9999-3333-2222
          access_key_id: foo
          secret_access_key: bar"
      }

      it "should have a user_id stripped of dashes" do
        subject.aws_user_id.should == '999933332222'
      end

      it { subject.aws_access_key_id.should == 'foo' }
      it { subject.aws_secret_access_key.should == 'bar' }
      it { subject.has_dns?.should be_false }
    end

    describe "with a DNS section" do
      let (:yaml) {
        "
        dns:
          username: bob
          domain: mydomain.com
          password: steve
          prefix: env
        "
      }
      it { subject.has_dns?.should be_true }
      it { subject.dns_username.should == 'bob' }
      it { subject.dns_domain.should == 'mydomain.com' }
      it { subject.dns_password.should == 'steve' }
      it { subject.dns_prefix.should == 'env' }
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
