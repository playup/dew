require 'spec_helper'

describe Account do

  describe '::read' do
    it "should look for the named account file in the ~/.dew/accounts dir" do
      name = 'a_development_name'
      YAML.should_receive(:load_file).with("#{ENV['HOME']}/.dew/accounts/#{name}.yaml").and_return({})
      Account.read(name)
    end
  end

  describe "parsing yaml" do
    before :each do
      YAML.stub(:load_file).and_return(yaml)
    end

    subject { Account.read('foo') }

    describe "with an aws section" do
      let (:yaml) do
        { 
          'aws' => {
            'user_id' => '9999-3333-2222',
            'access_key_id' => 'foo',
            'secret_access_key' => 'bar'
          }
        }
      end

      it "should have a user_id stripped of dashes" do
        subject.aws_user_id.should == '999933332222'
      end

      it { subject.aws_access_key_id.should == 'foo' }
      it { subject.aws_secret_access_key.should == 'bar' }
      it { subject.has_dns?.should be_false }
    end

    describe "with a DNS section" do
      let (:yaml) do
        {
          'dns' => {
            'domain' => 'mydomain.com',
            'key' => 'a1b2c3d4e5'
          }
        }
      end
      
      it { subject.should have_dns }
      its(:dns_key) { should == 'a1b2c3d4e5' }
      its(:dns_domain) { should == 'mydomain.com' }
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
