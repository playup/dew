require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

describe Database do

  let (:rds) { double('RDS', :servers => double('RDSServers')) }
  let (:id) { 'mydatabase' }
  let (:fog_database) { double('FogDatabase', :id => id) }
  
  before :each do
    Cloud.stub(:rds => rds)
    rds.servers.stub(:create => fog_database)
  end
  
  describe ".create!" do
    it "should ask Fog to create a new RDS with the provided name, size, username and password" do
      rds.servers.should_receive(:create).with(hash_including(:id => id, :flavor_id => 'db.m1.small', :master_username => 'root', :password => 'password'))
      Database.create!(id, 'db.m1.small', 'password')
    end
    
    it "should return a new Database object with an ID" do
      database = Database.create!(id, 'b', 'd')
      database.id.should == id
    end
  end
  
  describe ".get" do
    it "should return nil if the database doesn't exist" do
      rds.servers.should_receive(:get).with(id).and_return nil
      Database.get(id).should == nil
    end
    
    it "should return a Database object if the database does exist" do
      rds.servers.should_receive(:get).with(id).and_return fog_database
      Database.get(id).id.should == id
    end
      
  end
  
  context "with a database created" do
    before :each do
      @database = Database.create!(id, 'db.m1.small', 'password')
      fog_database.stub(:endpoint => {'Address' => '127.0.0.1'}, :master_username => 'root')
    end
    describe "db_environment_file" do
      it "should return the contents of a file to use as /etc/environment that can be used to connct to this database" do
        data = @database.db_environment_file('password')
        data.should =~ /PUGE_DB_NAME=#{id}/
        data.should =~ /PUGE_DB_USERNAME=root/
        data.should =~ /PUGE_DB_PASSWORD=password/
        data.should =~ /PUGE_DB_HOST=127.0.0.1/
      end
    end
    describe :public_address do
      it {@database.public_address.should == '127.0.0.1'}
    end 
  end
  
end