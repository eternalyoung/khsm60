require 'rails_helper'
require 'support/my_spec_helper'

describe Game, type: :model do
  # пользователь для создания игр
  let(:user) { create(:user) }

  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { create(:game_with_questions, user: user) }

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
      expect(game_w_questions.previous_level).to eq(1)
    end
  end

  describe '#answer_current_question!' do
    before { game_w_questions.answer_current_question!(answer_key) }
    context 'when answer is wrong' do
      let!(:answer_key) { (['a','b','c','d'] - [game_w_questions.current_game_question.correct_answer_key]).sample }
      it 'finishes the game' do
        expect(game_w_questions.finished?).to eq(true)
      end

      it 'finishes with status fail' do
          expect(game_w_questions.status).to eq(:fail)
      end
    end

    context 'when answer is correct' do
      let!(:level) { 0 }
      let!(:answer_key) { game_w_questions.current_game_question.correct_answer_key }

      context 'and question is last' do
        let!(:level) { Question::QUESTION_LEVELS.max }
        let!(:game_w_questions) { create(:game_with_questions, user: user, current_level: level) }

        it 'finishes the game' do
          expect(game_w_questions.finished?).to eq(true)
        end

        it 'finishes with status won' do
          expect(game_w_questions.status).to eq(:won)
        end
      end

      context 'and question is not last' do
        it 'moves to next level' do
          expect(game_w_questions.current_level).to eq(level + 1)
        end

        it 'continues game' do
          expect(game_w_questions.finished?).to eq(false)
        end
      end
      
      context 'and time is over' do
        let!(:game_w_questions) { create(:game_with_questions, user: user, created_at: Time.now - Game::TIME_LIMIT) }

        it 'finishes the game' do
          expect(game_w_questions.finished?).to eq(true)
        end

        it 'finishes with status timeout' do
          expect(game_w_questions.status).to eq(:timeout)
        end
      end
    end
  end
end
