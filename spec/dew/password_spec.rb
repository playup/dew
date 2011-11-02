require 'spec_helper'

describe Password do
  
  describe :random do
    it "should return a random string of characters each time it is called" do
      Password.random.should_not == Password.random
    end
  end
end
  
