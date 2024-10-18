def set_defaults!
  Setting.welcome_title = "Welcome to the Hackerspace Members Site"
  Setting.welcome_body = "<p>We are a member-driven community workshop where you can learn, make cool stuff, meet other cool people, and make your city a better place to live!</p><p>You don't have to be a member to come visit, but if you're interested in volunteering or being a member, feel free to sign up here! For more information, <a href=\"/more_info\">Click Here</a>.</p>"
  Setting.more_info_page = "No info here yet, bug a member about filling this part out!"
  Setting.member_resources_inset = "No info here yet, bug a member about filling this part out!"
  Setting.analytics_code = "<!-- insert analytics code here -->"
  Setting.space_api_json_template = '{
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
