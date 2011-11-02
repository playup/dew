require 'spec_helper'

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
      
      its(:ami) { should == 'ami-ccf405a5' }
      its(:count) { should == 2 }
      its(:size) { should == 'c1.medium' }
      its(:security_groups) { should == %w{non_default} }
      its(:keypair) { should == 'id_revo' }
      its(:username) { should == 'myusername' }
      
      it "should have a to_s" do
        subject.to_s.should == <<EOF
+-----------------+--------------------------------------------------------------------------------+
| 2 instances     | "c1.medium" (1.7 GB memory, 5 ECUs processor, 350 GB storage, 32-bit platform) |
| disk image      | "ami-ccf405a5"                                                                 |
| security groups | ["non_default"]                                                                |
| keypair         | "id_revo"                                                                      |
+-----------------+--------------------------------------------------------------------------------+
EOF
      end
    end

    context "defaults" do
      its(:username) { should == Profile::DEFAULT_USERNAME }
    end
    
    describe "without an elb or RDS section" do
      it { should_not have_elb }
      it { should_not have_rds }
    end
    
    describe "with an elb section" do
      let(:profile) do
        {
          'elb' => {
            'listener_ports' => [80, 443]
          }
        }
      end
      
      it { should have_elb }
      its(:elb_listener_ports) { should == [80, 443] }
    end
    
    describe "with an RDS section without a storage size" do
      let(:profile) do
        {
          'rds' => {
            'size' => 'db.m1.small'
          }
        }
      end
      
      it { should have_rds }
      its(:rds_size) { should == 'db.m1.small' }
      its(:rds_storage_size) { should == Profile::DEFAULT_RDS_STORAGE_SIZE }
    end

    describe "with an RDS section with a storage size" do
      let(:storage_size) { rand(24356) }

      let(:profile) do
        {
          'rds' => {
            'size' => 'db.m1.small',
            'storage' => storage_size
          }
        }
      end
      
      it { should have_rds }
      its(:rds_size) { should == 'db.m1.small' }
      its(:rds_storage_size) { should == storage_size }
    end
  end
  
  describe "#populate_from_yaml" do
    
    subject { x = Profile.new('blah'); x.populate_from_yaml('region', yaml); x }
    
    describe "instance_disk_size" do
  
      context "with" do      
        let(:instance_disk_size) { rand(235) }
        let(:yaml) { { 'instances' => { 'disk-size' => instance_disk_size } } }  
        its(:instance_disk_size) { should == instance_disk_size }
      end
      
      context "without" do
        let(:yaml) { { 'instances' => { } } }  
        its(:instance_disk_size) { should == nil }      
      end
    
    end
  end
end
