require 'rails_helper'

RSpec.describe GameQuestion, type: :model do

  let(:game_question) { create(:game_question, a: 2, b: 1, c: 4, d: 3) }
  context 'game status' do
    # тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq({'a' => game_question.question.answer2,
                                            'b' => game_question.question.answer1,
                                            'c' => game_question.question.answer4,
                                            'd' => game_question.question.answer3})
    end

    it 'correct .answer_correct?' do
      expect(game_question.answer_correct?('b')).to be_truthy
    end

    it 'correct .level & .text delegates' do
      expect(game_question.text).to eq(game_question.question.text)
      expect(game_question.level).to  eq(game_question.question.level)
    end
  end

  context 'user helpers' do
    it 'correct audience_help' do
      expect(game_question.help_hash).not_to include(:audience_help)

      game_question.add_audience_help

      expect(game_question.help_hash).to include(:audience_help)

      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end
  end

  describe "#correct_answer_key" do
    it 'returns correct answer key' do
      expect(game_question.correct_answer_key).to eq('b')
    end
  end

  describe "#help_hash" do
    it 'empty on create' do
      expect(game_question.help_hash).to eq({})
    end
    context "with some saved pairs" do
      before do
        game_question.help_hash[:key_test1] = 'test1'
        game_question.help_hash['key_test2'] = 'test2'
        game_question.save
      end

      it 'returns correct pairs' do
        expect(game_question.help_hash).to eq({key_test1: 'test1', 'key_test2' => 'test2'})
      end
    end
  end

  describe "#fifty_fifty" do
    it 'help_hash doesent have fifty_fifty key' do
      expect(game_question.help_hash).not_to include(:fifty_fifty)
    end
    context "with used fifty_fifty" do
      before { game_question.add_fifty_fifty }

      it 'writes fifty_fifty key' do
        expect(game_question.help_hash).to include(:fifty_fifty)
      end

      it 'has correct answer key' do
        expect(game_question.help_hash[:fifty_fifty]).to include('b')
      end

      it 'has 2 variants' do
        expect(game_question.help_hash[:fifty_fifty].size).to eq 2
      end
    end
  end

  describe "#friend_call" do
    it 'help_hash doesent have friend_call key' do
      expect(game_question.help_hash).not_to include(:friend_call)
    end
    context "with used friend_call" do
      before { game_question.add_friend_call }

      it 'writes friend_call key to help_hash' do
        expect(game_question.help_hash).to include(:friend_call)
      end

      it 'has answer letter' do
        expect(game_question.help_hash[:friend_call]).to match(/.*[ABCD]/)
      end
    end
  end
end
