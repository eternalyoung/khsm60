# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { create(:user) }
  # админ
  let(:admin) { create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { create(:game_with_questions, user: user) }

  # группа тестов для незалогиненного юзера (Анонимус)
  context 'Anon' do
    describe 'GET show' do
      before { get :show, id: game_w_questions.id }

      it 'response status not 200' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login page' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'shows alert flash' do
        expect(flash[:alert]).to be
      end
    end

    describe 'POST create' do
      before { post :create }

      it 'response status isnt 200' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login page' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'shows alert flash' do
        expect(flash[:alert]).to be
      end
    end

    describe 'PUT take_money' do
      before { put :take_money, id: game_w_questions.id }

      it 'response status isnt 200' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login page' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'shows alert flash' do
        expect(flash[:alert]).to be
      end
    end

    describe 'PUT answer' do
      before { put :answer, id: game_w_questions.id }

      it 'response status isnt 200' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login page' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'shows alert flash' do
        expect(flash[:alert]).to be
      end
    end

    describe 'PUT help' do
      before { put :help, id: game_w_questions.id }

      it 'response status isnt 200' do
        expect(response.status).not_to eq(200)
      end

      it 'redirects to login page' do
        expect(response).to redirect_to(new_user_session_path)
      end

      it 'shows alert flash' do
        expect(flash[:alert]).to be
      end
    end
  end

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    before { sign_in user }

    # юзер может создать новую игру
    it 'creates game' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер видит свою игру
    it '#show game' do
      get :show, id: game_w_questions.id
      game = assigns(:game) # вытаскиваем из контроллера поле @game
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)

      expect(response.status).to eq(200) # должен быть ответ HTTP 200
      expect(response).to render_template('show') # и отрендерить шаблон show
    end

    # юзер отвечает на игру корректно - игра продолжается
    it 'answers correct' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
    end

    # тест на отработку "помощи зала"
    it 'uses audience help' do
      # сперва проверяем что в подсказках текущего вопроса пусто
      expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
      expect(game_w_questions.audience_help_used).to be_falsey

      # фигачим запрос в контроллен с нужным типом
      put :help, id: game_w_questions.id, help_type: :audience_help
      game = assigns(:game)

      # проверяем, что игра не закончилась, что флажок установился, и подсказка записалась
      expect(game.finished?).to be_falsey
      expect(game.audience_help_used).to be_truthy
      expect(game.current_game_question.help_hash[:audience_help]).to be
      expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
      expect(response).to redirect_to(game_path(game))
    end

    describe 'GET show' do
      context "alien game" do
        before do
          alien_game = create(:game_with_questions)
          get :show, id: alien_game.id
        end

        it 'response status isnt 200' do
          expect(response.status).not_to eq(200)
        end

        it 'redirects to index page' do
          expect(response).to redirect_to(root_path)
        end

        it 'shows alert flash' do
          expect(flash[:alert]).to be
        end
      end
    end

    describe 'PUT take_money' do
      context 'with prize above zero' do
        before do
          game_w_questions.update_attribute(:current_level, 2)
          put :take_money, id: game_w_questions.id
        end
        it 'game ends' do
          game = assigns(:game)
          expect(game.finished?).to be_truthy
        end
        it 'game prize is correct' do
          game = assigns(:game)
          expect(game.prize).to eq(200)
        end
        it 'user balance is up correct' do
          user.reload
          expect(user.balance).to eq(200)
        end
        it 'redirects to user page' do
          expect(response).to redirect_to(user_path(user))
        end
        it 'shows warning flash' do
          expect(flash[:warning]).to be
        end
      end
    end

    describe 'POST create' do
      context "with not finished game" do
        before do
          game_w_questions
          post :create
        end

        it 'doesnt create a new game' do
          game = assigns(:game)
          expect(game).to be_nil
        end

        it 'redirects to not finished game page' do
          expect(response).to redirect_to(game_path(game_w_questions))
        end

        it 'shows alert flash' do
          expect(flash[:alert]).to be
        end
      end
    end

    describe 'PUT answer' do
      context "with incorrect answer" do
        before do
          game_w_questions
          put :answer, id: game_w_questions.id, letter: 'a'
        end

        it 'finishы game' do
          game = assigns(:game)
          expect(game.finished?).to eq(true)
        end

        it 'doesnt level up game level' do
          game = assigns(:game)
          expect(game.current_level).to be 0
        end

        it 'redirects to user page' do
          expect(response).to redirect_to(user_path(user.id))
        end

        it 'shows alert flash' do
          expect(flash[:alert]).to be
        end
      end
    end
    
    describe "PUT help" do
      context "fifty_fifty" do
        before do
          game_w_questions
          put :help, id: game_w_questions.id, help_type: :fifty_fifty
        end

        context "first use" do
          it 'redirects to game page' do
            expect(response).to redirect_to(game_path(game_w_questions))
          end
  
          it 'shows info flash' do
            expect(flash[:info]).to be
          end
        end

        context "not first use" do
          before do
            put :help, id: game_w_questions.id, help_type: :fifty_fifty
          end

          it 'redirects to game page' do
            expect(response).to redirect_to(game_path(game_w_questions))
          end
  
          it 'shows alert flash' do
            expect(flash[:alert]).to be
          end
        end
      end      
    end
  end
end
