require 'rails_helper'
require 'support/my_spec_helper'

describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { FactoryGirl.create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryGirl.create(:game_with_questions, user: user) }

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # генерим 60 вопросов с 4х запасом по полю level,
      # чтобы проверить работу RANDOM при создании игры
      generate_questions(60)

      game = nil
      # создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
      }.to change(Game, :count).by(1).and(# проверка: Game.count изменился на 1 (создали в базе 1 игру)
        change(GameQuestion, :count).by(15).and(# GameQuestion.count +15
          change(Question, :count).by(0) # Game.count не должен измениться
        )
      )
      # проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)
      # проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # тесты на основную игровую логику
  context 'game mechanics' do
    # правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)
      # ранее текущий вопрос стал предыдущим
      expect(game_w_questions.previous_game_question).to eq(q)
      expect(game_w_questions.current_game_question).not_to eq(q)
      # игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it '#take_money!' do
      # берем игру и отвечаем на текущий вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      # взяли деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  context '#status' do
    it 'returns :in_progress correctly' do
      expect(game_w_questions.status).to eq :in_progress
    end

    context 'finished' do
      before(:each) do
        game_w_questions.finished_at = Time.now
        expect(game_w_questions.finished?).to be_truthy
      end

      it 'returns :fail correctly' do
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq :fail
      end

      it 'returns :timeout correctly' do
        game_w_questions.finished_at += Game::TIME_LIMIT
        game_w_questions.is_failed = true
        expect(game_w_questions.status).to eq :timeout
      end

      it 'returns :won correctly' do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
        expect(game_w_questions.status).to eq :won
      end

      it 'returns :money correctly' do
        game_w_questions.take_money!
        expect(game_w_questions.status).to eq :money
      end
    end
  end

  describe '#current_game_question' do
    it 'returns current game question' do
      level = 2
      game_w_questions.current_level = level
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[level])
    end
  end

  describe '#previous_level' do
    it 'returns previous level' do
      level = 2
      game_w_questions.current_level = level
      expect(game_w_questions.previous_level).to eq(level - 1)
    end
  end

  describe '#answer_current_question!' do
    context 'given incorrect answer' do
      it 'should return false' do
        expect(game_w_questions.answer_current_question!('c')).to eq(false)
      end
      it 'should finish game' do
        game_w_questions.answer_current_question!('c')
        expect(game_w_questions.finished?).to eq(true)
      end

      it 'should fail game' do
        game_w_questions.answer_current_question!('c')
        expect(game_w_questions.is_failed).to eq(true)
      end
    end

    context 'given correct answer' do
      it 'should return true' do
        expect(game_w_questions.answer_current_question!('d')).to eq(true)
      end

      it 'should level up by 1' do
        level = game_w_questions.current_level
        game_w_questions.answer_current_question!('d')
        expect(game_w_questions.current_level).to eq(level + 1)
      end

      context 'on last question' do
        before(:each) do
          game_w_questions.current_level = Question::QUESTION_LEVELS.max
        end

        it 'should return true' do
          expect(game_w_questions.answer_current_question!('d')).to eq(true)
        end
        
        it 'should finish game' do
          game_w_questions.answer_current_question!('d')
          expect(game_w_questions.finished?).to eq(true)
        end

        it 'should not fail game' do
          game_w_questions.answer_current_question!('d')
          expect(game_w_questions.is_failed).to eq(false)
        end
      end

      context 'answer time_out' do
        it 'should return false' do
          game_w_questions.created_at -= Game::TIME_LIMIT
          expect(game_w_questions.answer_current_question!('d')).to eq(false)
        end
      end
    end
  end
end
