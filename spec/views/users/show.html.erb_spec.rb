require 'rails_helper'

describe 'users/show.html.erb', type: :view do
  before do
    assign(:user, user)
    assign(:games, [FactoryBot.build_stubbed(:game)])
    stub_template 'users/_game.html.erb' => 'User game goes here'
    render
  end
  let(:user) { create(:user, name: 'Вадик') }
 
  it "renders user name" do
    expect(rendered).to match 'Вадик'
  end

  it "displays game partial" do
    expect(rendered).to have_content 'User game goes here'
  end

  context "when not current users page" do
    it "doest render editor link" do
      expect(rendered).not_to match 'Сменить имя и пароль'
    end
  end

  context "when current users page" do
    before do 
      sign_in user 
      render
    end

    it "renders editor link" do
      expect(rendered).to match 'Сменить имя и пароль'
    end
  end
end
