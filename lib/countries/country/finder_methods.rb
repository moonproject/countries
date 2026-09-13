# frozen_string_literal: true

module ISO3166
  module CountryFinderMethods
    FIND_BY_REGEX = /^find_(all_)?(country_|countries_)?by_(.+)/
    SEARCH_TERM_FILTER_REGEX = /\(|\)|\[\]|,/
    ANY_NAME_ATTRIBUTES = %w[iso_long_name iso_short_name unofficial_names translated_names].freeze

    # :reek:FeatureEnvy
    def search(query)
      query = query.to_s if query.is_a?(Symbol)
      query = query.upcase if query&.match?(/[a-z]/)

      country = new(query)
      country&.valid? ? country : nil
    end

    def [](query)
      search(query)
    end

    # :reek:NestedIterators
    def find_all_by(attribute, val)
      attributes, lookup_value = parse_attributes(attribute, val)

      ISO3166::Data.cache.select do |_k, value|
        country = Country.cached_instance(value)
        attributes.any? do |attr|
          attr_value = value[attr] || country.send(attr)
          if attr_value.is_a?(Array)
            attr_value.any? do |v|
              v && lookup_value === cached(v) { parse_value(v) }
            end
          else
            attr_value && lookup_value === cached(attr_value) { parse_value(attr_value) }
          end
        end
      end
    end

    # :reek:FeatureEnvy
    def method_missing(method_name, *arguments)
      matches = method_name.to_s.match(FIND_BY_REGEX)
      super unless matches
      return_all = matches[1]
      method = matches[3]

      countries = find_by(method, arguments[0], matches[2])
      return_all ? countries : countries.last
    end

    # :reek:BooleanParameter
    def respond_to_missing?(method_name, include_private = false)
      matches = method_name.to_s.match(FIND_BY_REGEX)
      return super unless matches && matches[3]

      method = matches[3]

      instance_methods.include?(method.to_sym)
    end

    protected

    # :reek:ControlParameter
    def find_by(attribute, value, obj = nil)
      find_all_by(attribute.downcase, value).map do |country|
        obj ? new(country.last) : country
      end
    end

    def parse_attributes(attribute, val)
      raise "Invalid attribute name '#{attribute}'" unless searchable_attribute?(attribute.to_sym)

      attribute = attribute.to_s
      attributes = attribute == 'any_name' ? ANY_NAME_ATTRIBUTES : [attribute]

      [attributes, parse_value(val)]
    end

    # :reek:ManualDispatch
    # :reek:FeatureEnvy
    def parse_value(value)
      value = value.gsub(SEARCH_TERM_FILTER_REGEX, '').freeze if value.respond_to?(:gsub)
      strip_accents(value)
    end

    def searchable_attribute?(attribute)
      searchable_attributes.include?(attribute.to_sym)
    end

    def searchable_attributes
      @_searchable_attributes ||= (instance_methods - UNSEARCHABLE_METHODS + %i[any_name]).freeze
    end
  end
end
