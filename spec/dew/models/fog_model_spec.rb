require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

describe FogModel do
  let (:fog_object) { double('Fog Object', :id => 'i-12345') }
  
  before :each do
    @model = FogModel.new(fog_object)
  end
  
  it { @model.id.should == fog_object.id }
  
  describe :wait_until_ready do
    it "should call Fog's wait_for method to check that the object is ready" do
      fog_object.should_receive(:wait_for)
      @model.wait_until_ready
    end
  end
  
  it "should pass unrecognized methods on to its child object" do
    fog_object.should_receive(:wibble).with('hello').and_return('goodbye')
    @model.wibble('hello').should == 'goodbye'
  end
end
    