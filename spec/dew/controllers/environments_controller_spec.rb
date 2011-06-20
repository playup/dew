require File.expand_path(File.join(File.dirname(__FILE__), '../spec_helper'))

describe EnvironmentsController do
  subject { EnvironmentsController.new }

  after { subject }

  describe :create do
    let(:profile) { mock(:profile, :keypair => 'default') }
    before {
      @env = double(:environment)
      Profile.should_receive(:read).with('profile_name').and_return(profile)
      subject.stub(:agree => true)
    }

    after { subject.create(:name , 'profile_name', options) }


    context "no options" do
        let(:options) { {} }

        it "should ask the user for confirmation before destroying the environment" do
          Environment.should_receive(:create).with(:name, profile).and_return(@env)
          @env.should_receive(:show)
          subject.should_receive(:agree).and_return(true)
        end

        it "should not create the environment if agreement is not given" do
          subject.should_receive(:agree).and_return(false)
          @env.should_not_receive(:create)
        end
    end

    context ":force => true" do
        let(:options) { {:force => true} }

        it "should not ask for agreement" do
          Environment.should_receive(:create).with(:name, profile).and_return(@env)
          subject.should_not_receive(:agree)
          @env.should_receive(:show)
        end
    end
  end

  describe :index do
    after { subject.index }

    it "should index the environments" do
      Environment.should_receive(:index)
    end
  end

  describe :show do
    let(:name) { 'foo' }

    before {
      Environment.should_receive(:get).with(name).and_return(environment)
    }

    context "environment doesn't exist" do
      let(:environment) { nil }

      it "should raise an exception" do
        lambda { subject.show('foo') }.should raise_error /not found/
      end
    end

    context "environment exists" do
      let(:environment) { double('Environment') }

      after { subject.show(name) }

      it "should show an environment" do
        environment.should_receive(:show)
      end
    end

  end

  describe :destroy do
    let(:name) { 'foo' }

    before {
      Environment.should_receive(:get).with(name).and_return(environment)
    }

    context "environment doesn't exist" do
      let(:environment) { nil }

      it "should raise an exception" do
        lambda { subject.destroy(name) }.should raise_error /not found/
      end
    end

    context "environment exists" do
      let(:environment) { double('Environment', :destroy => true, :show => true) }

      before { subject.stub(:agree => true) }

      after { subject.destroy(name, options) }

      context "no options" do
        let(:options) { {} }

        it "should show the environment before destroying it" do
          environment.should_receive(:show)
        end

        it "should find an environment and destroy it if agreement is given" do
          environment.should_receive(:destroy)
        end

        it "should ask the user for confirmation before destroying the environment" do
          subject.should_receive(:agree).and_return(true)
        end

        it "should not destroy the environment if agreement is not given" do
          subject.should_receive(:agree).and_return(false)
          environment.should_not_receive(:destroy)
        end
      end

      context ":force => true" do
        let(:options) { {:force => true} }

        it "should not ask for agreement" do
          subject.should_not_receive(:agree)
          environment.should_receive(:destroy)
        end
      end
    end
  end
end
