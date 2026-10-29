module ApplicationHelper
  @payment_methods = [[nil],["PayPal"],["Dwolla"],["Bill Pay"],["Check"],["Cash"],["Other"]]
  @payment_instructions = {nil => nil, :paypal => "Set up a monthly recurring payment to hslfinances@gmail.com", :dwolla => "Set up a monthly recurring payment to hslfinances@gmail.com", :billpay =>  "Have your bank send a monthly check to HeatSync Labs Treasurer, 140 W Main St, Mesa AZ 85201", :check => "Mail to HeatSync Labs Treasurer, 140 W Main St, Mesa AZ 85201 OR put in the drop safe at the Lab with a deposit slip firmly attached each month.", :cash => "Put in the drop safe at the Lab with a deposit slip firmly attached each month.", :other => "Hmm... talk to a Treasurer!"}

  def sort_link(title, column, options = {})
    condition = options[:unless] if options.has_key?(:unless)
    sort_dir = params[:dir] == 'up' ? 'down' : 'up'
    link_to_unless condition, title, request.parameters.merge( {:sort => column, :dir => sort_dir} )
  end

  # A round avatar with initials and Gravatar (see AvatarComponent).
  def person_avatar(user, size = 40)
    render AvatarComponent.new(name: user.name, email: user.email, size: size)
  end

  # The choices for a member's level, as the membership forms offer them.
  def member_level_options
    [[nil], ["None", 0], ["Unable", 1], ["Volunteer", 10], ["Associate ($25)", 25], ["Basic ($50)", 50], ["Plus ($100)", 100]]
  end

  # A person's avatar and name together, linking to their page (or to `to`).
  def person_link(user, size: 28, to: user)
    link_to(to, class: "person-cell") { person_avatar(user, size) + tag.span(user.name) }
  end

  # Several controllers hand chart data as [JavaScript milliseconds, value]
  # pairs (the shape Highcharts took); this reads one back as lab time.
  def time_from_js(milliseconds)
    Time.zone.at(milliseconds / 1000)
  end

  # Charts draw with Chart.js, which only pages with a chart need. The first
  # chart on a page adds the script to the head; later calls do nothing.
  def load_chart_scripts
    return if @chart_scripts_loaded
    @chart_scripts_loaded = true
    content_for :head, javascript_import_module_tag("charts")
  end

  # The first sentence or line of a free-text field, for one-line summaries.
  def first_sentence(text)
    text.to_s.split(/[\n.;]/).map(&:strip).reject(&:blank?).first.to_s
  end
end
