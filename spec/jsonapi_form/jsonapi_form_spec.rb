# frozen_string_literal: true

class TestForm < JSONAPIForm::Base
  TYPE = 'foobar'.freeze

  ATTRIBUTES = %w[
    foo
    bar
  ].freeze

  RELATIONSHIPS = {
    'foobar' => { 'class_name' => 'TestForm' },
    'baz' => { 'class_name' => 'TestForm', 'is_collection' => true },
    'bazable' => { 'class_name' => { 'foobar' => 'TestSymbolsForm', 'baz' => 'TestForm' }, 'polymorphic' => true }
  }.freeze

  validates_numericality_of :foo, greater_than: 0, unless: -> { options[:skip_foo_validation].present? }
end

class TestSymbolsForm < JSONAPIForm::Base
  TYPE = :foobar

  ATTRIBUTES = %i[
    foo
    bar
  ].freeze

  RELATIONSHIPS = {
    foobar: { class_name: 'TestForm' },
    baz: { class_name: 'TestForm', is_collection: true },
    bazable: { class_name: { foobar: 'TestSymbolsForm', baz: 'TestForm' }, polymorphic: true }
  }.freeze

  validates_numericality_of :foo, greater_than: 0, unless: -> { options[:skip_foo_validation].present? }
end

RSpec.describe TestForm do
  let(:form) do
    {
      'data' => {
        'id' => 'string_id',
        'type' => 'foobar',
        'attributes' => {
          'foo' => 1,
          'bar' => 2
        },
        'relationships' => {
          'foobar' => {
            'data' => {
              'type' => 'foobar',
              'attributes' => {
                'foo' => 1,
                'bar' => 2
              }
            }
          },
          'baz' => {
            'data' => [
              {
                'type' => 'foobar',
                'attributes' => {
                  'foo' => 1,
                  'bar' => 2
                }
              }
            ]
          },
          'bazable' => {
            'data' => {
              'type' => 'foobar',
              'attributes' => {
                'foo' => 1,
                'bar' => 2
              }
            }
          }
        }
      }
    }
  end

  let(:invalid_to_many_relation_form) do
    {
      'data' => {
        'type' => 'foobar',
        'relationships' => {
          'baz' => {
            'data' => {
              'type' => 'foobar',
              'attributes' => {
                'foo' => 1,
                'bar' => 2
              }
            }
          }
        }
      }
    }
  end

  let(:invalid_to_one_relation_form) do
    {
      'data' => {
        'type' => 'foobar',
        'relationships' => {
          'foobar' => {
            'data' => [
              {
                'type' => 'foobar',
                'attributes' => {
                  'foo' => 1,
                  'bar' => 2
                }
              }
            ]
          }
        }
      }
    }
  end

  let(:invalid_polymorph_relation_form) do
    {
      'data' => {
        'type' => 'foobar',
        'relationships' => {
          'bazable' => {
            'data' => {
              'type' => 'foooooo',
              'attributes' => {
                'foo' => 1,
                'bar' => 2
              }
            }
          }
        }
      }
    }
  end

  context 'возвращает ошибку' do
    it 'если в корне нет поля data' do
      expect { described_class.new({}) }
        .to raise_error(JSONAPIForm::InvalidStructure, /Data invalid type in jsonapi spec/)
    end

    it 'если корневой data не объект' do
      expect { described_class.new('data' => '') }
        .to raise_error(JSONAPIForm::InvalidStructure, /Data invalid type in jsonapi spec/)
    end

    it 'если в корневом data нет поля type' do
      expect { described_class.new('data' => {}) }
        .to raise_error(JSONAPIForm::InvalidStructure, /Type invalid type in jsonapi spec/)
    end

    it 'если в корневом data поле type не строка' do
      expect { described_class.new('data' => { 'type' => {} }) }
        .to raise_error(JSONAPIForm::InvalidStructure, /Type invalid type in jsonapi spec/)
    end

    it 'если в корневом data есть поле attributes и оно не обект' do
      expect { described_class.new('data' => { 'type' => 'foobar', 'attributes' => 'foobar' }) }
        .to raise_error(JSONAPIForm::InvalidStructure, /Attributes invalid type in jsonapi spec/)
    end

    it 'если в корневом data поле type отличается от ожидаемого' do
      expect { described_class.new('data' => { 'type' => 'not_foobar' }) }
        .to raise_error(JSONAPIForm::InvalidStructure, /Type expected to be a foobar/)
    end

    it 'если в корневом data есть поле id и оно не строка' do
      form['data']['id'] = 1

      expect { described_class.new(form) }
        .to raise_error(JSONAPIForm::InvalidStructure, /Id invalid type in jsonapi spec/)
    end

    context 'при наличии relationships' do
      it 'если relationships не объект' do
        form['data']['relationships'] = 'foobar'

        expect { described_class.new(form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Relationships invalid type in jsonapi spec/)
      end

      it 'если поля relationships не объекты' do
        form['data']['relationships'] = { 'foobar' => 'barfoo' }

        expect { described_class.new(form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Relationships foobar invalid type in jsonapi spec/)
      end

      it 'если в релейшене ожидается коллекция, а пришёл элемент' do
        expect { described_class.new(invalid_to_many_relation_form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Relationships baz data invalid type in jsonapi spec/)
      end

      it 'если в релейшене ожидается элемент, а пришла коллекция' do
        expect { described_class.new(invalid_to_one_relation_form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Relationships foobar data invalid type in jsonapi spec/)
      end

      it 'если в полиморфном релейшене пришел неверный тип' do
        expect { described_class.new(invalid_polymorph_relation_form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Relationships bazable type has invalid value/)
      end
    end
  end

  context 'не возвращает ошибку' do
    it 'если в корневом data нет поля attributes' do
      expect { described_class.new('data' => { 'type' => 'foobar' }) }
        .not_to raise_error
    end
  end

  describe '#attributes' do
    it 'возвращает хешмапу переданных аттрибутов' do
      expect(described_class.new(form).attributes).to eq('bar' => 2, 'foo' => 1)
    end

    it 'возвращает пустой хэш если не переданн ключ аттрибутов' do
      form['data'].delete('attributes')

      expect(described_class.new(form).attributes).to eq({})
    end

    it 'возвращает пустой хэш если ключ аттрибутов nil' do
      form['data']['attributes'] = nil

      expect(described_class.new(form).attributes).to eq({})
    end

    it 'возвращает только переданные аттрибуты' do
      form['data']['attributes'].delete('bar')

      expect(described_class.new(form).attributes).to eq('foo' => 1)
    end
  end

  describe '#received_attributes' do
    it 'возвращает только переданные аттрибуты' do
      form['data']['attributes'].delete('bar')

      expect(described_class.new(form).received_attributes).to eq(['foo'])
    end
  end

  describe '#relationships' do
    it 'возвращает хешмапу переданных релейшенов' do
      expect(described_class.new(form).relationships.keys).to match_array(%w[foobar baz bazable])
    end

    it 'возвращает только переданные релейшены' do
      form['data']['relationships'].delete('baz')

      expect(described_class.new(form).relationships.keys).to eq(%w[foobar bazable])
    end

    it 'возвращает пустую хешмапу если релейшены не переданы' do
      form['data'].delete('relationships')
      expect(described_class.new(form).relationships).to eq({})
    end

    it 'для полиморфной связи выбирает нужную форму' do
      expect(described_class.new(form).bazable.class.name).to eq('TestSymbolsForm')
    end
  end

  describe '#id' do
    it 'возвращает переданный id объекта' do
      expect(described_class.new(form).id).to eq('string_id')
    end

    it 'attributes не содержит id' do
      expect(described_class.new(form).attributes).not_to include('id')
    end
  end

  describe '#need_destroy_relations' do
    it 'возвращает массив релейшенов помеченных на удаление: to one relation' do
      form['data']['relationships']['foobar']['data'] = nil
      obj = described_class.new(form)
      expect(obj.need_destroy_relations).to eq(['foobar'])
    end

    it 'возвращает массив релейшенов помеченных на удаление: to many relation' do
      form['data']['relationships']['baz']['data'] = []
      obj = described_class.new(form)
      expect(obj.need_destroy_relations).to eq(['baz'])
    end
  end

  context 'валидации' do
    it 'форма валидна' do
      expect(described_class.new(form).valid?).to eq(true)
    end

    it 'в корневой форме ошибка' do
      form['data']['attributes']['foo'] = -1
      expect(described_class.new(form).valid?).to eq(false)
    end

    it 'возвращает ошибку корневой формы' do
      form['data']['attributes']['foo'] = -1
      obj = described_class.new(form)
      obj.valid?

      expect(obj.errors.messages).to eq(foo: ['must be greater than 0'])
    end

    it 'в форме релейшена ошибка' do
      form['data']['relationships']['foobar']['data']['attributes']['foo'] = -1
      expect(described_class.new(form).valid?).to eq(false)
    end

    it 'возвращает ошибку формы релейшена' do
      form['data']['relationships']['foobar']['data']['attributes']['foo'] = -1
      obj = described_class.new(form)
      obj.valid?

      expect(obj.errors.messages).to eq("relationships.foobar": [{ foo: ['must be greater than 0'] }])
    end
  end

  describe 'пользовательские опции' do
    let(:options) { { skip_foo_validation: true } }
    it 'обрабатывает опции в корневой форме' do
      form['data']['attributes']['foo'] = -1
      expect(described_class.new(form, options).valid?).to eq(true)
    end

    it 'обрабатывает опции в форме релейшена' do
      form['data']['relationships']['foobar']['data']['attributes']['foo'] = -1
      expect(described_class.new(form, options).valid?).to eq(true)
    end
  end

  describe 'i18n' do
    before do
      I18n.locale = :ru
    end

    after do
      I18n.locale = :en
    end

    context 'использует локаль ru' do
      it 'если корневой data не объект' do
        expect { described_class.new('data' => '') }
          .to raise_error(JSONAPIForm::InvalidStructure, /Data имеет неверный тип в спецификации jsonapi/)
      end

      it 'если в корневом data поле type отличается от ожидаемого' do
        expect { described_class.new('data' => { 'type' => 'not_foobar' }) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Type ожидается тип foobar/)
      end
    end
  end

  describe 'форма с инлюдами' do
    let(:form) do
      {
        'data' => {
          'id' => 'string_id',
          'type' => 'foobar',
          'attributes' => {
            'foo' => 1,
            'bar' => 2
          },
          'relationships' => {
            'foobar' => {
              'data' => {
                'id' => '1',
                'type' => 'foobar'
              }
            },
            'baz' => {
              'data' => [
                {
                  'id' => '2',
                  'type' => 'foobar'
                }
              ]
            },
            'bazable' => {
              'data' => {
                'id' => '3',
                'type' => 'foobar'
              }
            }
          }
        },
        'included' => [
          {
            'id' => '1',
            'type' => 'foobar',
            'attributes' => {
              'foo' => 1,
              'bar' => 2
            }
          },
          {
            'id' => '2',
            'type' => 'foobar',
            'attributes' => {
              'foo' => 1,
              'bar' => 2
            }
          },
          {
            'id' => '3',
            'type' => 'foobar',
            'attributes' => {
              'foo' => 1,
              'bar' => 2
            }
          }
        ]
      }
    end

    let(:invalid_to_many_relation_form) do
      {
        'data' => {
          'type' => 'foobar',
          'relationships' => {
            'baz' => {
              'data' => {
                'id' => '5',
                'type' => 'foobar'
              }
            }
          }
        },
        'included' => [
          'id' => '5',
          'type' => 'foobar',
          'attributes' => {
            'foo' => 1,
            'bar' => 2
          }
        ]
      }
    end

    let(:invalid_to_one_relation_form) do
      {
        'data' => {
          'type' => 'foobar',
          'relationships' => {
            'foobar' => {
              'data' => [
                {
                  'id' => '3',
                  'type' => 'foobar'
                }
              ]
            }
          }
        },
        'included' => [
          {
            'id' => '3',
            'type' => 'foobar',
            'attributes' => {
              'foo' => 1,
              'bar' => 2
            }
          }
        ]
      }
    end

    let(:invalid_polymorph_relation_form) do
      {
        'data' => {
          'type' => 'foobar',
          'relationships' => {
            'bazable' => {
              'data' => {
                'id' => '1',
                'type' => 'foooooo'
              }
            }
          }
        },
        'included' => [
          {
            'id' => '1',
            'type' => 'foooooo',
            'attributes' => {
              'foo' => 1,
              'bar' => 2
            }
          }
        ]
      }
    end

    context 'возвращает ошибку' do
      it 'если в included не массив' do
        form['included'] = 'not an array'

        expect { described_class.new(form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Included invalid type in jsonapi spec/)
      end

      it 'если в included присутствуют не хэши' do
        form['included'] = [{ 'hash' => 1 }, 'string']

        expect { described_class.new(form) }
          .to raise_error(JSONAPIForm::InvalidStructure, /Included 1 invalid type in jsonapi spec/)
      end

      context 'при наличии relationships' do
        it 'если relationships не объект' do
          form['data']['relationships'] = 'foobar'

          expect { described_class.new(form) }
            .to raise_error(JSONAPIForm::InvalidStructure, /Relationships invalid type in jsonapi spec/)
        end

        it 'если поля relationships не объекты' do
          form['data']['relationships'] = { 'foobar' => 'barfoo' }

          expect { described_class.new(form) }
            .to raise_error(JSONAPIForm::InvalidStructure, /Relationships foobar invalid type in jsonapi spec/)
        end

        it 'если в релейшене ожидается коллекция, а пришёл элемент' do
          expect { described_class.new(invalid_to_many_relation_form) }
            .to raise_error(JSONAPIForm::InvalidStructure, /Relationships baz data invalid type in jsonapi spec/)
        end

        it 'если в релейшене ожидается элемент, а пришла коллекция' do
          expect { described_class.new(invalid_to_one_relation_form) }
            .to raise_error(JSONAPIForm::InvalidStructure, /Relationships foobar data invalid type in jsonapi spec/)
        end

        it 'если в полиморфном релейшене пришел неверный тип' do
          expect { described_class.new(invalid_polymorph_relation_form) }
            .to raise_error(JSONAPIForm::InvalidStructure, /Relationships bazable type has invalid value/)
        end
      end
    end

    describe '#relationships' do
      it 'возвращает хешмапу переданных релейшенов' do
        expect(described_class.new(form).relationships.keys).to match_array(%w[foobar baz bazable])
      end

      it 'возвращает только переданные релейшены' do
        form['data']['relationships'].delete('baz')

        expect(described_class.new(form).relationships.keys).to eq(%w[foobar bazable])
      end

      it 'возвращает пустую хешмапу если релейшены не переданы' do
        form['data'].delete('relationships')
        expect(described_class.new(form).relationships).to eq({})
      end

      it 'для полиморфной связи выбирает нужную форму' do
        expect(described_class.new(form).bazable.class.name).to eq('TestSymbolsForm')
      end
    end

    describe '#need_destroy_relations' do
      it 'возвращает массив релейшенов помеченных на удаление: to one relation' do
        form['data']['relationships']['foobar']['data'] = nil
        obj = described_class.new(form)
        expect(obj.need_destroy_relations).to eq(['foobar'])
      end

      it 'возвращает массив релейшенов помеченных на удаление: to many relation' do
        form['data']['relationships']['baz']['data'] = []
        obj = described_class.new(form)
        expect(obj.need_destroy_relations).to eq(['baz'])
      end
    end

    context 'валидации' do
      it 'форма валидна' do
        expect(described_class.new(form).valid?).to eq(true)
      end

      it 'в корневой форме ошибка' do
        form['data']['attributes']['foo'] = -1
        expect(described_class.new(form).valid?).to eq(false)
      end

      it 'возвращает ошибку корневой формы' do
        form['data']['attributes']['foo'] = -1
        obj = described_class.new(form)
        obj.valid?

        expect(obj.errors.messages).to eq(foo: ['must be greater than 0'])
      end

      it 'в форме релейшена ошибка' do
        form['included'][0]['attributes']['foo'] = -1
        expect(described_class.new(form).valid?).to eq(false)
      end

      it 'возвращает ошибку формы релейшена' do
        form['included'][0]['attributes']['foo'] = -1
        obj = described_class.new(form)
        obj.valid?

        expect(obj.errors.messages).to eq("relationships.foobar": [{ foo: ['must be greater than 0'] }])
      end
    end

    describe 'пользовательские опции' do
      let(:options) { { skip_foo_validation: true } }

      it 'обрабатывает опции в корневой форме' do
        form['data']['attributes']['foo'] = -1
        expect(described_class.new(form, options).valid?).to eq(true)
      end

      it 'обрабатывает опции в форме релейшена' do
        form['included'][0]['attributes']['foo'] = -1
        expect(described_class.new(form, options).valid?).to eq(true)
      end
    end
  end
end

RSpec.describe TestSymbolsForm do
  let(:symbols_form) do
    {
      data: {
        id: 'string_id',
        type: 'foobar',
        attributes: {
          foo: 1,
          bar: 2
        },
        relationships: {
          foobar: {
            data: {
              type: 'foobar',
              attributes: {
                foo: 1,
                bar: 2
              }
            }
          },
          baz: {
            data: [
              {
                type: 'foobar',
                attributes: {
                  foo: 1,
                  bar: 2
                }
              }
            ]
          },
          bazable: {
            data: {
              type: 'foobar',
              attributes: {
                foo: 1,
                bar: 2
              }
            }
          }
        }
      }
    }
  end

  context 'аттрибуты, релейшены, хеш, тип ресурса могут быть описаны символами' do
    it 'валидирует форму' do
      expect(described_class.new(symbols_form).valid?).to eq(true)
    end

    it 'возвращает переданные параметры' do
      obj = described_class.new(symbols_form)
      expect(obj.attributes.keys).to match_array(%w[foo bar])
    end

    it 'возвращает переданные релейшены' do
      obj = described_class.new(symbols_form)
      expect(obj.relationships.keys).to match_array(%w[foobar baz bazable])
    end
  end
end
