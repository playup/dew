require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

describe Profile do

  it "should look for profile file in the profiles dir" do
    YAML.should_receive(:load_file).with("#{ENV['HOME']}/.dew/profiles/puge.yaml").and_return({})
    Profile.read('puge')
  end

  describe "parsing yaml" do

    # TODO: This can be refactored to use subject to reduce lines of code.

    let(:profile) { { 'blank' => 'blank' } }

    before :each do
      YAML.stub(:load_file).and_return(profile)
      Cloud.stub(:region => 'ap-southeast-1')
      Cloud.stub_chain(:compute, :flavors, :detect => double(:flavor, :ram => 1.7, :cores => 5, :disk => 350, :bits => 32 ))
    end
    
    subject { Profile.read('development') }

    describe "with an instances section" do
      let(:profile) do
        {
          'instances' => {
            'amis' => {
              'ap-southeast-1' => 'ami-ccf405a5'
            },
            'size' => 'c1.medium',
            'count' => 2,
            'security-groups' => ['non_default'],
            'keypair' => 'id_revo',
            'username' => 'myusername'
          }
        }
      end
      
      it { subject.ami.should == 'ami-ccf405a5' }
      it { subject.count.should == 2 }
      it { subject.size.should == 'c1.medium' }
      it { subject.security_groups.should == %w{non_default} }
      it { subject.keypair.should == 'id_revo' }
      it { subject.username.should == 'myusername' }
      
      it "should have a to_s" do
        subject.to_s.should == <<EOF
+-----------------+----------------------------------------------------------------------------------------------------+
| 2 instances     | "c1.medium" (1.7 GB memory, 5 ECUs processor, 350 GB storage, 32-bit platform, ?? I/O performance) |
| disk image      | "ami-ccf405a5"                                                                                     |
| security groups | ["non_default"]                                                                                    |
| keypair         | "id_revo"                                                                                          |
+-----------------+----------------------------------------------------------------------------------------------------+
EOF
      end
    end

    it "should default to 'ubuntu' as the username" do
      subject.username.should == 'ubuntu'
    end
    
    describe "without an elb or RDS section" do
      it { subject.has_elb?.should be_false }
      it { subject.has_rds?.should be_false }
    end
    
    describe "with an elb section" do
      let(:profile) do
        {
          'elb' => {
            'listener_ports' => [80, 443]
          }
        }
      end
      
      it { subject.has_elb?.should be_true }
      it { subject.elb_listener_ports.should == [80, 443] }
    end
    
    describe "with an RDS section" do
      let(:profile) do
        {
          'rds' => {
            'size' => 'db.m1.small'
          }
        }
      end
      
      it { subject.has_rds?.should be_true }
      it { subject.rds_size.should == 'db.m1.small' }
    end
  end
end
