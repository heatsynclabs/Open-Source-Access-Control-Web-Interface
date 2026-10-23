# rails-settings-cached 2.x: settings are declared as fields with defaults.
# The seeds (db/seeds/defaults.rb) still assign these to persist overrides,
# and the defaults below keep every page rendering even before seeding.
class Setting < RailsSettings::Base
  cache_prefix { "v1" }

  field :welcome_title, type: :string,
        default: "Welcome to the Hackerspace Members Site"

  field :welcome_body, type: :string,
        default: "<p>We are a member-driven community workshop where you can learn, make cool stuff, meet other cool people, and make your city a better place to live!</p><p>You don't have to be a member to come visit, but if you're interested in volunteering or being a member, feel free to sign up here! For more information, <a href=\"/more_info\">Click Here</a>.</p>"

  field :more_info_page, type: :string,
        default: "No info here yet, bug a member about filling this part out!"

  field :member_resources_inset, type: :string,
        default: "No info here yet, bug a member about filling this part out!"

  field :analytics_code, type: :string,
        default: "<!-- insert analytics code here -->"

  field :space_api_json_template, type: :string, default: '{
    "api" : "0.12",
    "space" : "Your Hackerspace Name Here",
    "logo" : "http://example.com/logo.png",
    "lat": 0,
    "lon": -0,
    "icon":{
        "open": "http://example.com/open.png",
        "closed":"http://example.com/closed.png"
    },
    "url" : "http://example.com",
    "address" : "123 main st, city, state, country",
    "contact" : {
        "phone" : "",
        "irc" : "",
        "twitter" : "",
        "ml" : ""
    },
    "cam" : [""],
    "feeds" : [{"name" : "",
                "url"  : ""},
               {"name" : "",
               "url"  : ""}],
    "apis" : {
        "oac" : {
            "url" : "http://this-apps-url.example.com/door_access",
            "description" : "https://github.com/heatsynclabs/Open-Source-Access-Control-Web-Interface"
        },
        "pamela" : {
            "url" : "http://this-apps-url.example.com/macs.json",
            "description" : "https://github.com/heatsynclabs/Open-Source-Access-Control-Web-Interface"
        }
    }
  }'
end
