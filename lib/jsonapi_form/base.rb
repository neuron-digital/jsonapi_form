# frozen_string_literal: true

module JSONAPIForm
  # Базовый класс для форм
  # В потомках описываются аттрибуты, релейшены и валидации
  # Валидации из ActiveModel::Validations
  #
  # Пример класса-потомка
  #
  # class TestSymbolsForm < JSONAPIForm::Base
  #   TYPE = :foobar
  #
  #   ATTRIBUTES = %i[
  #     foo
  #     bar
  #   ].freeze
  #
  #   RELATIONSHIPS = {
  #     foobar: { class_name: 'TestForm' },
  #     baz: { class_name: 'TestForm', is_collection: true }
  #   }.freeze
  #
  #   validates_numericality_of :foo, greater_than: 0, unless: -> { options[:skip_foo_validation].present? }
  # end
  class Base
    include ActiveModel::Validations

    validate :check_relationships

    ATTRIBUTES = [].freeze
    RELATIONSHIPS = {}.freeze

    # @return [Array<String>] список пришедших аттрибутов формы
    attr_reader :received_attributes

    # @return [Array<String>] список имён релейшенов которые необходимо удалить
    attr_reader :need_destroy_relations

    # @return [String] id объекта
    attr_accessor :id

    # @return [String] тип объекта
    attr_accessor :type

    # @return [Hash] пользовательские опции
    attr_accessor :options

    # Создаёт объект формы, проверяет его структуру
    # Если структура не подходит по спецификации jsonapi, вызывает исключение JSONAPIForm::InvalidStructure
    #
    # MyForm.new({data: {type: 'my_resource', attributes: {name: 'Phil'}}}, {do_not_validate_name: true})
    #
    # @param: jsonapi_hash [Hash] - хэш формата jsonapi
    # @param: options [Hash] - пользовательский хэш, доступен в объектах формы
    def initialize(jsonapi_hash, options = {})
      prepare_declared_data
      define_accessors
      @need_destroy_relations = []
      @options = HashWithIndifferentAccess.new(options)

      validate_base(jsonapi_hash)

      jsonapi_hash = HashWithIndifferentAccess.new(jsonapi_hash)

      validate_internal(jsonapi_hash)
      fetch_attrs(jsonapi_hash)
      write_attrs(jsonapi_hash.dig('data', 'attributes'))
      write_id(jsonapi_hash.dig('data'))
      write_type(jsonapi_hash.dig('data'))

      return unless jsonapi_hash.dig('data', 'relationships').present?

      write_relationships(jsonapi_hash.dig('data', 'relationships'))
    end

    # Возвращает хэш переданных атрибутов
    # form = MyForm.new({data: {type: 'my_resource', attributes: {name: 'Phil'}}}, {do_not_validate_name: true})
    # form.attributes # => {'name' => 'Phil'}
    #
    # @return: [ActiveSupport::HashWithIndifferentAccess]
    def attributes
      result = @_declared_attributes.inject({}) do |res, attr|
        @received_attributes.include?(attr) ? res.merge!(attr => send(attr.to_sym)) : res
      end

      HashWithIndifferentAccess.new result
    end

    # Возвращает хэш переданных релейшенов
    # form = MyForm.new({data: {type: 'my_resource', relationships: {foo: {data: {type: 'foo', id: 'id'}}}})
    # form.relationships # => {'foo' => foo_form_object}
    #
    # @return: [ActiveSupport::HashWithIndifferentAccess]
    def relationships
      @_declared_relationships.each_with_object({}) do |(k, _v), h|
        h[k] = send(k.to_sym) if @received_relationships.include?(k)
        h
      end
    end

    private

    # Достаёт данные из текущего класса-потомка и приводит их к строкам
    def prepare_declared_data
      @_declared_attributes = self.class::ATTRIBUTES.map(&:to_s)
      @_declared_relationships = HashWithIndifferentAccess.new(
          self.class::RELATIONSHIPS.deep_dup.deep_stringify_keys
      )
      @_declared_type = self.class::TYPE.to_s
    end

    # Определяет аксессоры для атрибутов и релейшенов
    def define_accessors
      (@_declared_attributes + @_declared_relationships.keys).each do |attr|
        self.class.send(:define_method, attr) { instance_variable_get("@#{attr}") }
        self.class.send(:define_method, "#{attr}=") { |val| instance_variable_set("@#{attr}", val) }
      end
    end

    def fetch_attrs(args)
      @received_attributes = args.dig('data', 'attributes')&.keys || []
      @received_included = args.dig('included') || []
      @received_relationships = []
    end

    def write_attrs(attrs)
      return unless attrs

      attrs.slice(*@_declared_attributes).each do |k, v|
        instance_variable_set "@#{k}", v
      end
    end

    def write_id(data)
      @id = data['id']
    end

    def write_type(data)
      @type = data['type']
    end

    def write_relationships(relationships)
      @received_relationships = relationships.keys

      relationships.slice(*@_declared_relationships.keys).each do |k, v|
        instance_variable_set "@#{k}", init_relationship(k, v.dig('data'))
      end
    end

    def init_relationship(key, data)
      if data.is_a?(Array) && data.empty? || data.nil?
        @need_destroy_relations.push key
        return data
      end

      if @_declared_relationships[key]['polymorphic'] == true
        init_polymorphic_relation_form(key, data)
      else
        init_relation_form(data, @_declared_relationships[key]['class_name'])
      end
    end

    def init_polymorphic_relation_form(key, data)
      type = data.dig('type')

      errors.add(:"relationships.#{key}.type", I18n.t('errors.jsonapi_form.invalid_relation_type')) unless
        @_declared_relationships[key]['class_name'].key?(type)

      raise InvalidStructure.new(errors) unless errors.empty?

      init_relation_form(data, @_declared_relationships[key]['class_name'][type])
    end

    def init_relation_form(data, class_name)
      if data.is_a?(Array)
        data.map {|val| class_name.constantize.new({'data' => relation_data(val)}, @options)}
      else
        class_name.constantize.new({'data' => relation_data(data)}, @options)
      end
    end

    def relation_data(data)
      return data unless data['id'].present?

      included_data = @received_included.select { |i| i.dig('id') == data['id'] && i.dig('type') == data['type'] }.first

      return data unless included_data.present?

      included_data
    end

    def validate_base(params)
      validate_data(params, :base, [Hash])
      raise InvalidStructure.new(errors) unless errors.empty?
    end

    def validate_internal(params)
      validate_data(params.dig('data'), :data, [Hash, Array])
      raise InvalidStructure.new(errors) unless errors.empty?

      validate_data(params['included'], :included, [Array]) if params.dig('included').present?

      if params.dig('included').present? && errors.empty?
        params['included'].each_with_index do |included, index|
          validate_data(included, :"included.#{index}", [Hash])
        end
      end

      validate_data(params.dig('data', 'id'), :id, [String, NilClass])
      validate_data(params.dig('data', 'type'), :type, [String])
      validate_data(params.dig('data', 'attributes'), :attributes, [Hash, NilClass])
      validate_resource_type(params.dig('data', 'type'))
      validate_relationships(params)

      raise InvalidStructure.new(errors) unless errors.empty?
    end

    def validate_data(params, pointer, classes)
      return if classes.map {|k| params.is_a?(k)}.include?(true)

      errors.add(pointer, I18n.t('errors.jsonapi_form.invalid_type'))
    end

    def validate_relationships(params)
      return if params.dig('data')&.key?('relationships').blank?

      return errors.add(:relationships, I18n.t('errors.jsonapi_form.invalid_type')) unless
        params.dig('data', 'relationships')&.is_a?(Hash)

      validate_relationships_struct(params.dig('data', 'relationships'))
      return if errors.any?

      validate_relationships_type(params.dig('data', 'relationships'))
    end

    def validate_relationships_struct(params)
      params.each do |k, v|
        if v.is_a?(Hash)
          validate_data(v, :"relationships.#{k}.data", [Hash])
        else
          errors.add(:"relationships.#{k}", I18n.t('errors.jsonapi_form.invalid_type'))
        end
      end
    end

    def validate_relationships_type(params)
      params.each do |relation, value|
        allowed_classes = []
        if @_declared_relationships.dig(relation, 'is_collection')
          allowed_classes.push Array
        else
          allowed_classes.push Hash, NilClass
        end
        validate_data(value['data'], :"relationships.#{relation}.data", allowed_classes)
      end
    end

    def validate_resource_type(type)
      errors.add :type, I18n.t('errors.jsonapi_form.resource_type.invalid', valid_type: @_declared_type) if
        type != @_declared_type
    end

    def check_relationships
      relationships.except(*@need_destroy_relations).each do |k, v|
        if v.is_a?(Array)
          check_relationships_array(k, v)
        else
          check_relationships_data(k, v)
        end
      end
    end

    def check_relationships_array(key, value)
      value.map {|data| check_relationships_data(key, data)}
    end

    def check_relationships_data(key, data)
      errors.add(:"relationships.#{key}", data.errors.messages) unless data.valid?
    end
  end
end
