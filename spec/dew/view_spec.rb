require 'spec_helper'

describe String do
  describe :indent do
    it { "Hi there\nHow are you?\n".indent(2).should == "  Hi there\n  How are you?\n" }
    it { "  Hi there\n  How are you?\n".indent(-2).should == "Hi there\nHow are you?\n" }
  end
end

describe View do
  subject {
    View.new('Test', [double(:id => 1, :name => 'one'), double(:id => 2, :name => 'two')], [:id, :name]) }

  describe :index do
    it { subject.index.should == <<EOF
Test:
  +----+-------+
  | id | name  |
  +----+-------+
  | 1  | "one" |
  | 2  | "two" |
  +----+-------+
EOF
    }
  end

  describe :show do
    it {
      subject.show(0).should == <<EOF
Test:
  +------+-------+
  | id   | 1     |
  | name | "one" |
  +------+-------+
EOF
      }
  end
end
