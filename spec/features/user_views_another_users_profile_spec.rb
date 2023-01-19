require 'rails_helper'

RSpec.feature 'USER views another users profile', type: :feature do
  let(:main_user) { create(:user, name: 'Антон') }
  let(:user) { create(:user, name: 'Вадик') }

  let!(:game1) { create(:game_with_questions, user: user, created_at: Time.parse('2023.01.17, 10:00 KRAT'), finished_at: Time.parse('2023.01.17, 10:10'), current_level: 6, prize: 777, is_failed: true) }
  let!(:game2) { create(:game_with_questions, user: user, created_at: Time.parse('2023.01.17, 11:00 KRAT'), finished_at: Time.parse('2023.01.17, 10:10'), current_level: 8, prize: 3) }

  before { login_as main_user }

  scenario 'successfully' do
    visit '/'
    click_link 'Вадик'
    expect(page).to have_current_path "/users/#{user.id}"

    expect(page).to have_content 'Вадик'
    expect(page).not_to have_content 'Сменить имя и пароль'

    expect(page).to have_content 'деньги'
    expect(page).to have_content '17 янв., 06:00'
    expect(page).to have_content '8'
    expect(page).to have_content '3 ₽'

    expect(page).to have_content 'проигрыш'
    expect(page).to have_content '17 янв., 07:00'
    expect(page).to have_content '6'
    expect(page).to have_content '777 ₽'
  end
end
