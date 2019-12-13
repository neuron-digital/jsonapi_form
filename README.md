# JSONAPIForm

Реализация форм обджектов для удобной работы с входящими jsonapi данными содержащими relationships

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jsonapi_form'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jsonapi_form

## Usage

```
class SampleForm < JSONAPIForm::Base
  TYPE = :user

  ATTRIBUTES = %i[
    name
    city
  ].freeze

  RELATIONSHIPS = {
    avatars: { class_name: 'AvatarForm', is_collection: true },
    file: { class_name: { image: 'ImageForm', video: 'VideoForm' }, polymorphic: true }
  }.freeze

  validates_presence_of :name, unless: -> { options[:my_option_skip_name_validation].present? }
end

class AvatarForm < JSONAPIForm::Base
  TYPE = :avatar

  ATTRIBUTES = %i[
    link
  ].freeze

  validates_presence_of :link
end

class ImageForm < JSONAPIForm::Base
  TYPE = :image

  ATTRIBUTES = %i[
    link
  ].freeze

  validates_presence_of :link
end

class VideoForm < JSONAPIForm::Base
  TYPE = :video

  ATTRIBUTES = %i[
    link
    duration
  ].freeze

  validates_presence_of :link, :duration
end

data = {
  data: {
    id: 'user_id',
    type: 'user',
    attributes: {
      name: 'Alex'
    },
    relationships: {
      avatars: {
        data: [
          {
            type: 'avatar',
            id: 'some_avatar_id',
            attributes: {
              link: 'https://some/link'
            }
          }
        ]
      },
      file: {
        data: {
          type: 'video',
          id: 'some_video_id',
          attributes: {
            link: 'https://some/link',
            duration: 60
          }
        }
      }
    }
  }
}

OR

data = {
  data: {
    id: 'user_id',
    type: 'user',
    attributes: {
      name: 'Alex'
    },
    relationships: {
      avatars: {
        data: [
          {
            type: 'avatar',
            id: 'some_avatar_id'
          }
        ]
      },
      file: {
        data: {
          type: 'video',
          id: 'some_video_id'
        }
      }
    }
  },
  included: [
    {
      id: 'some_avatar_id',
      type: 'avatar',
      attributes: {
        link: 'https://some/link'
      }
    },
    {
      id: 'some_video_id',
      type: 'video',
      attributes: {
        link: 'https://some/link',
        duration: 60
      }
    }
  ]
}

form = SampleForm.new(data, my_option_skip_name_validation: true) # => can raise InvalidStructure
form.valid? # => bool
form.errors # => ActiveModel::Errors
form.attributes # => {'name' => 'Alex'}
form.received_attributes # => ['name']
form.relationships # => {'avatars': [AvatarForm], 'file': VideoForm}
form.avatars # => [AvatarForm]
form.need_destroy_relations # => [String];
form.id # => 'user_id'
form.avatars[0].id # => 'some_avatar_id'
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/jsonapi_form.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
